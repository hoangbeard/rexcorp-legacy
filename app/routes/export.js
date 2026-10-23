"use strict";

const { exec } = require("child_process");

// Xuất báo cáo đóng góp ra file nén để gửi cho bộ phận kế toán.
function ExportHandler() {
    this.exportReport = (req, res, next) => {
        const name = req.query.name;
        exec("tar -czf /tmp/" + name + ".tgz /var/rexcorp/reports", (err) => {
            if (err) return next(err);
            return res.download("/tmp/" + name + ".tgz");
        });
    };
}

module.exports = ExportHandler;
