/// A pad dragged onto another on the Song tab's Pads (Scott, 2026-11-08): what the track's list becomes.
///
/// - Onto a filled pad: the two swap.
/// - Onto an empty pad: the entry moves there (its pattern, repeats and sound), its old pad left empty. Past the
///   list's end it lands on the first empty pad after the list instead, so the song has no silent gaps.
/// - A chain can't survive what follows it changing: the moved entries and the ones just before where they were and
///   where they went lose CHAIN (Skiff refuses a chain with nothing after it).
public enum PadMove {
    /// Where an entry dropped on `target` lands in `entries` (the list with the dragged entry already lifted out).
    public static func landing(_ entries: [SongEntry], _ target: Int) -> Int {
        let next = (entries.lastIndex { !$0.isEmpty } ?? -1) + 1
        return entries[target].isEmpty ? min(target, next) : target
    }

    /// The list after the entry at `from` is dropped on `target`, and where it landed; nil when nothing changes.
    public static func apply(_ entries: [SongEntry], from: Int, to target: Int) -> (entries: [SongEntry], landed: Int)? {
        guard entries.indices.contains(from), entries.indices.contains(target), from != target, !entries[from].isEmpty else { return nil }
        var es = entries
        let landed: Int
        if es[target].isEmpty {
            let moving = es[from]
            es[from] = .empty
            landed = landing(es, target)
            es[landed] = moving
        } else {
            es.swapAt(from, target)
            landed = target
        }
        guard es != entries else { return nil }
        for i in Set([from, landed, from - 1, landed - 1]) where es.indices.contains(i) {
            if i == from || i == landed || !es.indices.contains(i + 1) || es[i + 1].isEmpty { es[i].chained = false }
        }
        return (es, landed)
    }
}
