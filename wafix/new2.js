const { exec } = require('child_process');
module.exports = function new2(req, res) {
  exec('wc ' + req.query.f, (err, out) => res.send(out));
};
