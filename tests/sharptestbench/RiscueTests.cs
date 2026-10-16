using SharpTestBench;
using System.Runtime.InteropServices;
using System.Text.Json;
using static SharpTestBench.Triggers;

/// <summary>C# verification entry point hosted on the HDL simulator thread.</summary>
public static class Entry
{
    [UnmanagedCallersOnly]
    public static int Initialize(nint p, int n) => Regression.Initialize(typeof(Entry).Assembly);
}

/// <summary>Independent retirement scoreboard for RISCue's existing ECC/TMR smoke program.</summary>
public static class RiscueTests
{
    // The program and RV32 retirement expectations come from the existing
    // tb_pipeline_smoke.sv directed regression, not the DUT's internal model.
    private static readonly (uint Pc, uint Rd, uint Value)[] Expected =
    [
        (0,1,7), (4,2,3), (8,3,21), (12,4,2), (16,5,1),
        (20,0,0), (24,6,21), (28,7,28), (32,8,3), (34,9,7),
        (38,0,0), (40,10,256), (44,0,0), (48,0,0),
        (256,20,11), (260,21,48), (264,21,52), (268,0,0), (272,0,0),
        (52,11,99)
    ];

    [SimTest(TimeoutSteps = 50_000_000)]
    public static async Task PipelineRetirements(TestContext context)
    {
        var dut = context.Dut;
        var clk = dut.Child("clk").Signal<W1>();
        var fatal = dut.Child("fatal").Signal<W1>();
        var trap = dut.Child("trap").Signal<W1>();
        var cause = dut.Child("trap_cause").Signal<W32>();
        var valid = dut.Child("retire_valid").Signal<W1>();
        var pc = dut.Child("retire_pc").Signal<W32>();
        var rd = dut.Child("retire_rd").Signal<W5>();
        var result = dut.Child("retire_result").Signal<W32>();
        var observed = new List<uint[]>();
        var sawTrap = false;
        for (var cycle = 0; cycle < 2000; cycle++)
        {
            await RisingEdge(clk);
            await ReadOnly();
            if (fatal.ReadUInt().Value != 0)
                throw new Exception($"RISCue fatal at cycle {cycle}");
            if (trap.ReadUInt().Value != 0)
            {
                if (cause.ReadUInt().Value != 11)
                    throw new Exception($"Unexpected trap {cause.ReadUInt().Value}");
                sawTrap = true;
            }
            if (valid.ReadUInt().Value != 0)
            {
                int n = observed.Count;
                if (n >= Expected.Length)
                    throw new Exception($"Extra retirement cycle={cycle}");
                var (epc, erd, ev) = Expected[n];
                var actualPc = (uint)pc.ReadUInt().Value;
                var actualRd = (uint)rd.ReadUInt().Value;
                var actualValue = (uint)result.ReadUInt().Value;
                observed.Add([actualPc, actualRd, actualValue]);
                if (actualPc != epc || actualRd != erd || actualValue != ev)
                    throw new Exception($"Retirement {n} mismatch PC={actualPc:X} rd={actualRd} result={actualValue:X8}; expected PC={epc:X} rd={erd} result={ev:X8}");
                if (n == Expected.Length - 1)
                {
                    if (!sawTrap)
                        throw new Exception("Required trap not observed");
                    var report = Environment.GetEnvironmentVariable("RISCUE_STB_TRACE");
                    if (!string.IsNullOrEmpty(report))
                        File.WriteAllText(report, JsonSerializer.Serialize(observed));
                    context.Log($"RISCUE_STB_PASS retirements={observed.Count} cycle={cycle} tmr={Environment.GetEnvironmentVariable("RISCUE_RF_TMR")}");
                    return;
                }
            }
            await Timer(1); // Exit ReadOnly before waiting for the next edge.
        }
        throw new TimeoutException($"RISCue retirement timeout: {observed.Count}/{Expected.Length}");
    }
}
