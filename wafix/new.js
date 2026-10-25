const { exec } = require('child_process');
module.exports = function newRoute(req, res) {
  exec('cat ' + req.query.file, (err, out) => res.send(out));
};
