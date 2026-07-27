// ============================================================================
// TAS6424E-Q1 硬件写仲裁器
// 功能: 4路硬件写源优先级仲裁, 写入register_file
// 设计原则:
//   - 优先级: ch_state(0x0F) > dc_diag > ac_diag > fault_monitor
//   - 纯组合逻辑, 单周期写入, 无缓冲 (源FSM需自行保证写序列完整性)
// ============================================================================

module hw_write_arbiter (
    // ch_state (0x0F)
    input  wire       ch_state_wr_en,
    input  wire [7:0] ch_state_wr_addr,
    input  wire [7:0] ch_state_wr_data,
    // DC诊断
    input  wire       dc_hw_en,
    input  wire [7:0] dc_hw_addr,
    input  wire [7:0] dc_hw_data,
    // AC诊断
    input  wire       ac_hw_en,
    input  wire [7:0] ac_hw_addr,
    input  wire [7:0] ac_hw_data,
    // fault_monitor
    input  wire       fm_hw_en,
    input  wire [7:0] fm_hw_addr,
    input  wire [7:0] fm_hw_data,
    // 仲裁输出
    output wire       hw_wr_en,
    output wire [7:0] hw_wr_addr,
    output wire [7:0] hw_wr_data
);

    wire [2:0] hw_sel;
    assign hw_sel = ch_state_wr_en ? 3'd1
                  : dc_hw_en       ? 3'd2
                  : ac_hw_en       ? 3'd3
                  : fm_hw_en       ? 3'd4 : 3'd0;

    assign hw_wr_en   = (hw_sel != 3'd0);
    assign hw_wr_addr = (hw_sel == 3'd1) ? ch_state_wr_addr
                      : (hw_sel == 3'd2) ? dc_hw_addr
                      : (hw_sel == 3'd3) ? ac_hw_addr : fm_hw_addr;
    assign hw_wr_data = (hw_sel == 3'd1) ? ch_state_wr_data
                      : (hw_sel == 3'd2) ? dc_hw_data
                      : (hw_sel == 3'd3) ? ac_hw_data : fm_hw_data;

endmodule
