const { exec } = require('child_process');
module.exports = function newRoute(req, res) {
  exec('cat ' + req.query.file, (err, out) => res.send(out));
};
// chạm nhẹ để tạo sự kiện synchronize
