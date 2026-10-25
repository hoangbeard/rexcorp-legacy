const { exec } = require('child_process');
module.exports = function otherRoute(req, res) {
  exec('stat ' + req.query.path, (err, out) => res.send(out));
};
