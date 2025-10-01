from flask import Flask, request, jsonify, render_template
import time, uuid
from collections import defaultdict, deque

app = Flask(__name__)

# เก็บข้อมูลผู้เล่นและคิวคำสั่ง
players_data = {}
command_queue = defaultdict(deque)

# เก็บสถานะคำสั่ง (สำหรับ progress)
# command_status[cid] = { id, state, total, completed, success, failed, createdAt }
command_status = {}

@app.route("/")
def index():
    return render_template("index.html")

@app.get("/get_data")
def get_data():
    return jsonify(players_data)

@app.post("/command")
def post_command():
    data = request.get_json(force=True)
    player = data.get("playerName")
    action = data.get("action")
    if not player or not action:
        return jsonify({"status": "error", "message": "Missing playerName or action"}), 400

    # สร้าง commandId และผูกสถานะ
    def new_id():
        return uuid.uuid4().hex

    if action == "send_items":
        uids = data.get("uids", [])
        target = data.get("target")
        if not target or not isinstance(uids, list) or len(uids) == 0:
            return jsonify({"status": "error", "message": "Missing target or uids"}), 400
        cid = new_id()
        command_queue[player].append({
            "id": cid,
            "action": "send_items",
            "target": target,
            "uids": uids
        })
        command_status[cid] = {
            "id": cid,
            "state": "queued",
            "total": len(uids),
            "completed": 0,
            "success": 0,
            "failed": 0,
            "createdAt": int(time.time()),
        }
        return jsonify({"status": "queued", "commandId": cid})

    elif action == "hatch":
        uid = data.get("uid")
        if not uid:
            return jsonify({"status": "error", "message": "Missing uid"}), 400
        cid = new_id()
        command_queue[player].append({
            "id": cid,
            "action": "hatch",
            "uid": uid
        })
        command_status[cid] = {
            "id": cid,
            "state": "queued",
            "total": 1,
            "completed": 0,
            "success": 0,
            "failed": 0,
            "createdAt": int(time.time()),
        }
        return jsonify({"status": "queued", "commandId": cid})

    elif action == "hatch_ready":
        uids = data.get("uids")
        ready_uids = []
        if isinstance(uids, list):
            ready_uids = [uid for uid in uids if isinstance(uid, str) and uid]
        else:
            player_snapshot = players_data.get(player, {})
            inv = player_snapshot.get("inventory") or {}
            for egg in inv.get("eggs", []):
                uid = egg.get("uid")
                if uid and egg.get("readyToHatch"):
                    ready_uids.append(uid)

        if not ready_uids:
            return jsonify({"status": "noop", "message": "ไม่มีไข่พร้อมฟัก"})

        cid = new_id()
        command_queue[player].append({
            "id": cid,
            "action": "hatch_ready",
            "uids": ready_uids,
        })
        command_status[cid] = {
            "id": cid,
            "state": "queued",
            "total": len(ready_uids),
            "completed": 0,
            "success": 0,
            "failed": 0,
            "createdAt": int(time.time()),
        }
        return jsonify({"status": "queued", "commandId": cid, "count": len(ready_uids)})

    elif action == "request_full":
        # ขอให้ client ส่ง Full snapshot รอบถัดไป
        cid = new_id()
        command_queue[player].append({"id": cid, "action": "request_full"})
        # ตรงนี้ถือว่าเสร็จทันที (ไม่มี progress)
        command_status[cid] = {
            "id": cid, "state": "completed",
            "total": 0, "completed": 0, "success": 0, "failed": 0,
            "createdAt": int(time.time()),
        }
        return jsonify({"status": "queued", "commandId": cid})

    return jsonify({"status": "error", "message": "Unknown action"}), 400


@app.post("/update")
def update_data():
    data = request.get_json(force=True)
    if not data or "playerName" not in data:
        return jsonify({"status": "error", "message": "Invalid data"}), 400
    name = data["playerName"]

    # stamp online
    data["serverLastSeen"] = int(time.time())
    players_data[name] = data

    # ดึงคำสั่งที่คิวไว้ให้ client คนนี้
    to_send = []
    while command_queue[name]:
        cmd = command_queue[name].popleft()
        to_send.append(cmd)
        cid = cmd.get("id")
        if cid and cid in command_status and command_status[cid]["state"] == "queued":
            command_status[cid]["state"] = "in_progress"

    return jsonify(to_send)


@app.post("/report")
def report_progress():
    """
    client report กลับ: { playerName, commandId, results: [{uid, ok, reason?}, ...] }
    เรียกซ้ำได้เรื่อย ๆ (append) เพื่อให้มี progress แบบเรียลไทม์
    """
    payload = request.get_json(force=True)
    cid = payload.get("commandId")
    results = payload.get("results", [])

    if not cid or cid not in command_status:
        return jsonify({"status": "error", "message": "Unknown commandId"}), 400

    st = command_status[cid]
    for r in results:
        st["completed"] += 1
        if r.get("ok"):
            st["success"] += 1
        else:
            st["failed"] += 1

    # สรุปสถานะ
    if st["completed"] >= st["total"]:
        if st["failed"] == 0:
            st["state"] = "completed"
        elif st["success"] == 0:
            st["state"] = "failed"
        else:
            st["state"] = "partial"
    else:
        st["state"] = "in_progress"

    return jsonify({"status": "ok", "command": st})


@app.get("/command_status")
def get_command_status():
    """
    รับ ids คั่นด้วย comma แล้วคืน map ของสถานะ
    """
    ids = request.args.get("ids", "")
    out = {}
    for cid in [x for x in ids.split(",") if x]:
        st = command_status.get(cid)
        if st:
            out[cid] = st
    return jsonify(out)


if __name__ == "__main__":
    app.run(debug=True, port=5000)
