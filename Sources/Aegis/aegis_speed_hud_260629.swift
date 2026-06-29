// aegis_speed_hud_260629.swift
// Added 260629: Cerebras speed HUD — the judging-criterion centerpiece ("Show Cerebras
// speed"). Per-agent tokens/sec + total latency from the response time_info, plus an
// aggregate banner. This is what makes the multi-agent fan-out visibly instant.
import SwiftUI

struct SpeedHUDView: View {
    let timings: [AgentTiming]
    let aggregateTokensPerSec: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bolt.fill").foregroundColor(.yellow)
                Text("CEREBRAS · gemma-4-31b")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                if aggregateTokensPerSec > 0 {
                    Text("\(Int(aggregateTokensPerSec)) tok/s avg")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            Divider()
            if timings.isEmpty {
                Text("Awaiting agents…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                ForEach(timings) { t in
                    HStack {
                        Text(t.agent)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                        Text("\(Int(t.tokensPerSec)) tok/s")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(width: 80, alignment: .leading)
                        Text("\(t.completionTokens) tok")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 64, alignment: .leading)
                        Text("\(t.totalMs) ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.85))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
