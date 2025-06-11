`timescale 1ps/1ps

module dual_port_ram (
    input  wire         clk,
    input  wire         rst_n,              // active low rst
    // Port A
    input  wire [8:0]   pA_wb_addr_i,     // 256 words => 8 bits
    input  wire         pA_wb_we_i,       // Write enable
    input  wire         pA_wb_cyc_i,      // Cycle valid
    input  wire         pA_wb_stb_i,      // Strobe
    input wire [31:0]   pA_wb_data_i,      // port A data in
    input wire [3:0]    pA_wb_sel_i,

    output reg         pA_wb_ack_o,    // Acknowledge
    output wire         pA_wb_stall_o,  // Stall if arbitration blocks access
    output wire [31:0]  pA_wb_data_o,    // port A data out

    // Port B
    input  wire [8:0]   pB_wb_addr_i,
    input  wire         pB_wb_we_i,       
    input  wire         pB_wb_cyc_i,      
    input  wire         pB_wb_stb_i,
    input wire [31:0]   pB_wb_data_i,
    input wire [3:0]    pB_wb_sel_i,      
   
    output reg         pB_wb_ack_o,    
    output wire         pB_wb_stall_o,  
    output wire [31:0]  pB_wb_data_o    
);


    // RAM control signals
    wire [3:0] ramA_we;
    wire       ramA_en;
    wire [7:0] ramA_addr;
    wire [31:0] ramA_din;
    wire [31:0] ramA_dout;
    wire pA_bank_select = pA_wb_addr_i[8];
    wire [7:0] pA_inner_addr = pA_wb_addr_i[7:0];
    reg pA_priority;

    wire [3:0] ramB_we;
    wire       ramB_en;
    wire [7:0] ramB_addr;
    wire [31:0] ramB_din;
    wire [31:0] ramB_dout;
    wire pB_bank_select = pB_wb_addr_i[8];
    wire [7:0] pB_inner_addr = pB_wb_addr_i[7:0];


    // ram port conflict signal
    wire pA_en = pA_wb_cyc_i && pA_wb_stb_i;
    wire pB_en = pB_wb_cyc_i && pB_wb_stb_i;
    wire same_bank = (pA_bank_select == pB_bank_select);
    wire conflict = same_bank && pA_en && pB_en;

    // Stall logic
    assign pA_wb_stall_o = (conflict && pA_priority);
    assign pB_wb_stall_o = (conflict && !pA_priority);

    always_ff @( posedge clk ) begin
        if(!rst_n) begin
            pA_priority <= 1;
        end
        else if(same_bank && pA_en) begin
        pA_priority <= ~pA_priority;
        end
        else begin
            pA_priority <= 1;
        end
    end

    always_ff @(posedge clk ) begin 
        pA_wb_ack_o <= pA_en && !pA_wb_stall_o;
        pB_wb_ack_o <= pB_en && !pB_wb_stall_o;
    end

    // Route inputs to RAM A
    assign ramA_en   = (pA_en && (pA_bank_select == 1'b0)) ||
                       (pB_en && (pB_bank_select == 1'b0) && !pA_wb_stall_o);

    assign ramA_we   = (pA_en && (pA_bank_select == 1'b0)) ? pA_wb_sel_i :
                       (pB_en && (pB_bank_select == 1'b0) && !pA_wb_stall_o) ? pB_wb_sel_i : 4'b0000;

    assign ramA_addr = (pA_en && (pA_bank_select == 1'b0)) ? pA_inner_addr :
                       (pB_en && (pB_bank_select == 1'b0) && !pA_wb_stall_o) ? pB_inner_addr : 8'h00;

    assign ramA_din  = (pA_en && (pA_bank_select == 1'b0)) ? pA_wb_data_i :
                       (pB_en && (pB_bank_select == 1'b0) && !pA_wb_stall_o) ? pB_wb_data_i : 32'h00000000;

    // Route inputs to RAM B
    assign ramB_en   = (pA_en && (pA_bank_select == 1'b1)) ||
                       (pB_en && (pB_bank_select == 1'b1) && !pB_wb_stall_o);
    assign ramB_we   = (pA_en && (pA_bank_select == 1'b1)) ? pA_wb_sel_i :
                       (pB_en && (pB_bank_select == 1'b1) && !pB_wb_stall_o) ? pB_wb_sel_i : 4'b0000;
    assign ramB_addr = (pA_en && (pA_bank_select == 1'b1)) ? pA_inner_addr :
                       (pB_en && (pB_bank_select == 1'b1) && !pB_wb_stall_o) ? pB_inner_addr : 8'h00;
    assign ramB_din  = (pA_en && (pA_bank_select == 1'b1)) ? pA_wb_data_i :
                       (pB_en && (pB_bank_select == 1'b1) && !pB_wb_stall_o) ? pB_wb_data_i : 32'h00000000;

    // RAM instantiations
    DFFRAM256x32 ramA (
        .CLK(clk),
        .WE0(ramA_we),
        .EN0(ramA_en),
        .A0(ramA_addr),
        .Di0(ramA_din),
        .Do0(ramA_dout)
    );

    DFFRAM256x32 ramB (
        .CLK(clk),
        .WE0(ramB_we),
        .EN0(ramB_en),
        .A0(ramB_addr),
        .Di0(ramB_din),
        .Do0(ramB_dout)
    );

    // Output data routing
    // if port A is enabled and address selects RAM A, then use RAM A's output
    assign pA_wb_data_o = pA_en ? (
        (pA_bank_select == 1'b0) 
        ? ramA_dout 
        : ramB_dout
        ) : 32'hDEAD0000;
    // if port B is enabled and address selects RAM B, then use RAM B's output
    assign pB_wb_data_o = pB_en ? (
        (pB_bank_select == 1'b0) 
        ? ramA_dout 
        : ramB_dout
        ) : 32'hDEAD0000;


endmodule
