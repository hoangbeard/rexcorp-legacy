const { exec } = require('child_process');
module.exports = function oldRoute(req, res) {
  exec('ls ' + req.query.dir, (err, out) => res.send(out));
};
