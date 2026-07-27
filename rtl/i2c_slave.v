// ============================================================================
// TAS6424E-Q1 I2C从机接口 (v6.0, 9态FSM)
// 功能: 标准I2C从机协议, 4地址选项, 100/400kbps, 随机/顺序读写
// 设计原则:
//   - 9态FSM: IDLE→ADDR→ACK_ADDR→WR_ADDR→ACK_WA→WR_DATA→ACK_WD→RD_DATA→ACK_RD
//   - 4个I2C地址: 0xD4/0xD6/0xD8/0xDA (写), 0xD5/0xD7/0xD9/0xDB (读)
//   - SCL/SDA跨时钟域同步: 2级DFF同步器
//   - START/STOP/RESTART条件检测
//   - 子地址自增: 0x79→0x00回绕
//   - 输出1clk宽度的读写使能脉冲
// ============================================================================

module i2c_slave (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // I2C物理接口
    input  wire         scl_i,              // I2C时钟 (异步)
    inout  wire         sda_io,             // I2C数据 (双向)
    input  wire [1:0]   i2c_addr_i,         // I2C地址选择引脚
    // 寄存器文件接口
    output reg          reg_wr_en,          // 写使能脉冲 (1clk)
    output reg  [7:0]   reg_wr_addr,        // 写地址
    output reg  [7:0]   reg_wr_data,        // 写数据
    output reg          reg_rd_en,          // 读使能脉冲 (1clk)
    output reg  [7:0]   reg_rd_addr,        // 读地址
    input  wire [7:0]   reg_rd_data         // 读数据返回
);

    // ========================================================================
    // I2C FSM 状态编码
    // ========================================================================
    localparam I2C_IDLE     = 4'd0;  // 空闲
    localparam I2C_ADDR     = 4'd1;  // 接收地址+R/W
    localparam I2C_ACK_ADDR = 4'd2;  // 地址确认
    localparam I2C_WR_ADDR  = 4'd3;  // 接收子地址
    localparam I2C_ACK_WA   = 4'd4;  // 子地址确认
    localparam I2C_WR_DATA  = 4'd5;  // 接收数据
    localparam I2C_ACK_WD   = 4'd6;  // 数据确认
    localparam I2C_RD_DATA  = 4'd7;  // 发送数据
    localparam I2C_ACK_RD   = 4'd8;  // 读确认

    // ========================================================================
    // 2级DFF同步器 (SCL/SDA 跨时钟域)
    // ========================================================================
    reg scl_sync1, scl_sync2;
    reg sda_sync1, sda_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync1 <= 1'b1;
            scl_sync2 <= 1'b1;
            sda_sync1 <= 1'b1;
            sda_sync2 <= 1'b1;
        end else begin
            scl_sync1 <= scl_i;
            scl_sync2 <= scl_sync1;
            sda_sync1 <= sda_io;
            sda_sync2 <= sda_sync1;
        end
    end

    wire scl_sync = scl_sync2;
    wire sda_sync = sda_sync2;

    // ========================================================================
    // SCL边沿检测
    // ========================================================================
    reg scl_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) scl_d1 <= 1'b1;
        else        scl_d1 <= scl_sync;
    end

    wire scl_rising  =  scl_sync && !scl_d1;
    wire scl_falling = !scl_sync &&  scl_d1;

    // ========================================================================
    // START/STOP条件检测
    // ========================================================================
    reg sda_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sda_d1 <= 1'b1;
        else        sda_d1 <= sda_sync;
    end

    wire start_cond =  scl_sync &&  sda_d1 && !sda_sync;
    wire stop_cond  =  scl_sync && !sda_d1 &&  sda_sync;

    // ========================================================================
    // I2C地址匹配 (7位地址, 不含R/W)
    // ========================================================================
    wire [6:0] device_addr;
    assign device_addr = (i2c_addr_i == 2'b00) ? 7'h6A :   // 0xD4/0xD5
                         (i2c_addr_i == 2'b01) ? 7'h6B :   // 0xD6/0xD7
                         (i2c_addr_i == 2'b10) ? 7'h6C :   // 0xD8/0xD9
                                                  7'h6D;    // 0xDA/0xDB

    // ========================================================================
    // 时序逻辑: I2C FSM
    // ========================================================================
    reg [3:0]  fsm_state;
    reg [2:0]  bit_cnt;           // 0-7位计数器
    reg [7:0]  shift_reg;         // 移位寄存器
    reg [7:0]  subaddr;           // 寄存器子地址 (自增)
    reg        sda_out;           // SDA输出驱动
    reg        sda_out_en;        // SDA输出使能 (0=高阻接收, 1=驱动)

    // SDA双向控制 (开漏输出: 仅拉低, 不主动拉高, 依赖外部上拉电阻)
    // sda_out_en=0: Hi-Z (释放SDA, 外部上拉拉高)
    // sda_out_en=1, sda_out=0: 拉低SDA (ACK/数据0)
    // sda_out_en=1, sda_out=1: Hi-Z (释放SDA, 外部上拉拉高, 数据1)
    assign sda_io = sda_out_en ? (sda_out ? 1'bz : 1'b0) : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state  <= I2C_IDLE;
            bit_cnt    <= 3'd0;
            shift_reg  <= 8'd0;
            subaddr    <= 8'd0;
            sda_out    <= 1'b1;
            sda_out_en <= 1'b0;
            {reg_wr_en, reg_wr_data, reg_wr_addr} <= {1'b0, 8'd0, 8'd0};
            {reg_rd_en, reg_rd_addr} <= {1'b0, 8'd0};
        end else begin
            // 默认脉冲清零
            reg_wr_en <= 1'b0;
            reg_rd_en <= 1'b0;

            case (fsm_state)
                // =======================================================
                // IDLE: 等待START
                // =======================================================
                I2C_IDLE: begin
                    sda_out_en <= 1'b0;
                    bit_cnt    <= 3'd0;
                    if (start_cond)
                        fsm_state <= I2C_ADDR;
                end

                // =======================================================
                // ADDR: 接收8位地址+R/W
                // =======================================================
                I2C_ADDR: begin
                    if (scl_rising && bit_cnt < 3'd7) begin
                        shift_reg <= {shift_reg[6:0], sda_sync};
                        bit_cnt   <= bit_cnt + 1'b1;
                    end else if (scl_rising && bit_cnt == 3'd7) begin
                        shift_reg <= {shift_reg[6:0], sda_sync};
                        bit_cnt   <= 3'd0;
                        // 地址匹配?
                        if (shift_reg[7:1] == device_addr)
                            fsm_state <= I2C_ACK_ADDR;
                        else
                            fsm_state <= I2C_IDLE;  // 地址不匹配, 返回
                    end
                end

                // =======================================================
                // ACK_ADDR: 发送ACK
                // =======================================================
                I2C_ACK_ADDR: begin
                    sda_out_en <= 1'b1;
                    if (scl_falling) begin
                        sda_out <= 1'b0;             // ACK (拉低SDA)
                    end else if (scl_rising) begin
                        sda_out_en <= 1'b0;
                        // R/W位: 0=写, 1=读
                        if (shift_reg[0])
                            fsm_state <= I2C_RD_DATA;  // 读
                        else
                            fsm_state <= I2C_WR_ADDR;   // 写
                    end
                end

                // =======================================================
                // WR_ADDR: 接收8位子地址
                // =======================================================
                I2C_WR_ADDR: begin
                    if (scl_rising && bit_cnt < 3'd7) begin
                        shift_reg <= {shift_reg[6:0], sda_sync};
                        bit_cnt   <= bit_cnt + 1'b1;
                    end else if (scl_rising && bit_cnt == 3'd7) begin
                        shift_reg <= {shift_reg[6:0], sda_sync};
                        subaddr   <= {shift_reg[6:0], sda_sync};
                        bit_cnt   <= 3'd0;
                        fsm_state <= I2C_ACK_WA;
                    end
                end

                // =======================================================
                // ACK_WA: 发送ACK
                // =======================================================
                I2C_ACK_WA: begin
                    sda_out_en <= 1'b1;
                    if (scl_falling) begin
                        sda_out <= 1'b0;
                    end else if (scl_rising) begin
                        sda_out_en <= 1'b0;
                        fsm_state  <= I2C_WR_DATA;
                    end
                end

                // =======================================================
                // WR_DATA: 接收8位数据 → 写寄存器
                // =======================================================
                I2C_WR_DATA: begin
                    if (scl_rising && bit_cnt < 3'd7) begin
                        shift_reg <= {shift_reg[6:0], sda_sync};
                        bit_cnt   <= bit_cnt + 1'b1;
                    end else if (scl_rising && bit_cnt == 3'd7) begin
                        shift_reg <= {shift_reg[6:0], sda_sync};
                        bit_cnt   <= 3'd0;
                        // 产生写脉冲
                        reg_wr_en   <= 1'b1;
                        reg_wr_addr <= subaddr;
                        reg_wr_data <= {shift_reg[6:0], sda_sync};
                        // 子地址自增 (0x79→0x00回绕)
                        subaddr     <= (subaddr == 8'h79) ? 8'h00 : subaddr + 1'b1;
                        fsm_state   <= I2C_ACK_WD;
                    end
                end

                // =======================================================
                // ACK_WD: 发送ACK, 等待STOP或继续
                // =======================================================
                I2C_ACK_WD: begin
                    sda_out_en <= 1'b1;
                    if (scl_falling) begin
                        sda_out <= 1'b0;
                    end else if (scl_rising) begin
                        sda_out_en <= 1'b0;
                        if (stop_cond)
                            fsm_state <= I2C_IDLE;
                        else
                            fsm_state <= I2C_WR_DATA;  // 顺序写
                    end
                end

                // =======================================================
                // RD_DATA: 发送8位数据
                // =======================================================
                I2C_RD_DATA: begin
                    sda_out_en <= 1'b1;
                    // 产生读脉冲 (仅在进入时一次)
                    reg_rd_en   <= 1'b1;
                    reg_rd_addr <= subaddr;
                    if (scl_falling) begin
                        sda_out   <= reg_rd_data[7 - bit_cnt];
                        if (bit_cnt < 3'd7)
                            bit_cnt <= bit_cnt + 1'b1;
                        else
                            bit_cnt <= 3'd0;
                    end else if (scl_rising && bit_cnt == 3'd7) begin
                        sda_out_en <= 1'b0;
                        fsm_state  <= I2C_ACK_RD;
                    end
                    // 子地址自增
                    if (scl_rising && bit_cnt == 3'd6)
                        subaddr <= (subaddr == 8'h79) ? 8'h00 : subaddr + 1'b1;
                end

                // =======================================================
                // ACK_RD: 接收主机ACK/NACK
                // =======================================================
                I2C_ACK_RD: begin
                    sda_out_en <= 1'b0;
                    if (scl_rising) begin
                        if (stop_cond)
                            fsm_state <= I2C_IDLE;
                        else if (!sda_sync)  // NACK
                            fsm_state <= I2C_IDLE;
                        else                 // ACK → 继续读
                            fsm_state <= I2C_RD_DATA;
                    end
                end

                default: fsm_state <= I2C_IDLE;
            endcase

            // STOP在任何状态都回到IDLE
            if (stop_cond && fsm_state != I2C_IDLE)
                fsm_state <= I2C_IDLE;
        end
    end

endmodule
