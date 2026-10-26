function find(col, userId, threshold) {
  // ruleid: rexcorp-mongo-where-injection
  col.find({ $where: `this.userId == ${userId} && this.stocks > '${threshold}'` });
  // ruleid: rexcorp-mongo-where-injection
  col.find({ $where: "this.stocks > '" + threshold + "'" });
  // ok: rexcorp-mongo-where-injection
  col.find({ $where: "this.stocks > 10" });
  // ok: rexcorp-mongo-where-injection
  col.find({ userId: userId, stocks: { $gt: Number(threshold) } });
}
