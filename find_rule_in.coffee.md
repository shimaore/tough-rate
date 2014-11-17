    module.exports = find_rule_in = (destination,database) =>
      ids = ("rule:#{destination[0...l]}" for l in [0..destination.length]).reverse()

      database.allDocs keys:ids, include_docs: true
      .then ({rows}) =>
        rule = (row.doc for row in rows when row.doc? and not row.doc.disabled)[0]
