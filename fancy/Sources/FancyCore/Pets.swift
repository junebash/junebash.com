public enum Pets {
  /// One for each cat in the house.
  public static let cats = [
    #"""
      /\_/\
     ( o.o )
      > ^ <
     /     \
    (_|   |_)
    """#,
    #"""
       /\___/\
      (  -.-  )
     (  _   _  )
      `-'---'-'
    """#,
    #"""
         /\_/\
     .--( u.u )
    (    `---' )  z
     `--------'  z
    """#,
    #"""
     /\_/\    /
    ( ^.^ )__/
     (        )
      ||    ||
    """#,
  ]

  public static let dog = #"ruff! ruff! (that's dog for "not a real command")"#

  /// Two steps of a cat walking left.
  public static let walking = [
    #"""
     /\_/\____,
    ( o.o     )\
     /_/   \_\
    """#,
    #"""
     /\_/\____,
    ( o.o     )\
      \_\  /_/
    """#,
  ]

  /// What a cat types walking leftward over a keyboard: a few neighbouring keys, each held a while.
  public static func pawPrints(using generator: inout some RandomNumberGenerator) -> String {
    let rows = ["qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"]
    let row = Array(rows.randomElement(using: &generator)!)
    var index = Int.random(in: 4..<row.count, using: &generator)
    var prints = ""
    for _ in 0..<Int.random(in: 3...5, using: &generator) where index >= 0 {
      prints += String(repeating: row[index], count: Int.random(in: 2...8, using: &generator))
      index -= Int.random(in: 1...2, using: &generator)
    }
    return prints
  }
}
