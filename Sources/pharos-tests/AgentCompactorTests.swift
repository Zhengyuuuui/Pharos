import Foundation
import PharosCore

func testAgentCompactorSQL() {
    // 1. OpenCode Level 1
    let op1 = AgentCompactor.deletionSQL(for: .openCode, options: CompactionOptions(level: .level1StreamEvents))
    expectEq(op1.count, 1, "Level 1 has 1 SQL statement")
    expect(op1.first?.contains("message.part.updated%") == true, "targets message.part.updated")
    expect(op1.first?.contains("message.updated%") == true, "targets message.updated")
    expect(op1.first?.contains("session.updated%") == true, "targets session.updated")

    // 2. OpenCode Level 2
    let op2 = AgentCompactor.deletionSQL(for: .openCode, options: CompactionOptions(level: .level2Checkpoints, daysOld: 30))
    expectEq(op2.count, 2, "Level 2 with daysOld has 2 SQL statements")
    expect(op2.first?.contains("message.removed%") == true, "Level 2 includes message.removed")
    expect(op2[1].contains("time_created <") == true, "Level 2 includes age threshold")

    // 3. Cursor Level 1
    let cur1 = AgentCompactor.deletionSQL(for: .cursor, options: CompactionOptions(level: .level1StreamEvents))
    expectEq(cur1.count, 1, "Cursor level 1 has 1 statement")
    expect(cur1.first?.contains("agentKv:%") == true, "Cursor targets agentKv")

    // 4. Cursor Level 2
    let cur2 = AgentCompactor.deletionSQL(for: .cursor, options: CompactionOptions(level: .level2Checkpoints))
    expectEq(cur2.count, 1, "Cursor level 2 has 1 statement")
    expect(cur2.first?.contains("checkpointId:%") == true, "Cursor level 2 targets checkpointId")
}
