`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 06:50:44 PM
// Design Name: 
// Module Name: I2c_bit_level
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// i2c single-master 
// * Limitation
//     * only function as I2C master
//     * no arbitration (i.e., no other master allowed)
//     * do not support slave "clock-stretching"
// * Input
//     cmd (command):  000:start, 001:write, 010:read, 011:stop, 100:restart
//     din: write:8-bit data;  read:LSB is ack/nack bit used in read
// * Output:
//     dout: received data
//     ack: received ack in write (should be 0)
// * Basic design
//     * external system
//          * generate proper start-write/read-stop condition
//          * use LSB of din (ack/nack) to indicate last byte in read
//     * FSM 
//          * loop 9 times for read/write (8 bit data + ack)
//          * no distinction between read/write 
//            (data  shift-in/shift-out simultaneously)
//     * Output control circuit   
//          * data out of sdat: loops 0-7 of write and loop 8 of read (send ack/nack)
//          * data into sdat: loops 0-7 of read and loop 8 of write (receive ack)
//    * dvsr: divisor to obtain a quarter of i2c clock period 
//          * 0.5*(# clk in SCK period) 
//          
// during a read operation, the LSB of din is the NACK bit
// i.e., indicate whether the current read is the last one in read cycle

module i2c_master(
   input clk, reset,
   input [7:0] din,
   input [15:0] dvsr,
   input [2:0] cmd,
   input wr_i2c,
   output tri scl,
   inout tri sda,
   output ready, done_tick, ack,
   output [7:0] dout
);

   // command constants
   localparam START_CMD   =3'b000;
   localparam WR_CMD      =3'b001;
   localparam RD_CMD      =3'b010;
   localparam STOP_CMD    =3'b011;
   localparam RESTART_CMD =3'b100;

   // FSM states
   localparam idle      =4'd0,
              hold      =4'd1,
              start1    =4'd2,
              start2    =4'd3,
              data1     =4'd4,
              data2     =4'd5,
              data3     =4'd6,
              data4     =4'd7,
              data_end  =4'd8,
              restart   =4'd9,
              stop1     =4'd10,
              stop2     =4'd11;

   // registers
   reg [3:0] state_reg, state_next;
   reg [15:0] c_reg, c_next;
   wire [15:0] qutr, half;

   reg [8:0] tx_reg, tx_next;
   reg [8:0] rx_reg, rx_next;

   reg [2:0] cmd_reg, cmd_next;
   reg [3:0] bit_reg, bit_next;

   reg sda_out, scl_out;
   reg sda_reg, scl_reg;
   reg data_phase;

   reg done_tick_i, ready_i;
   wire into, nack;

   //****************************************************************
   // SDA/SCL buffers
   //****************************************************************
   always @(posedge clk or posedge reset)
   begin
      if (reset) begin
         sda_reg <= 1'b1;
         scl_reg <= 1'b1;
      end
      else begin
         sda_reg <= sda_out;
         scl_reg <= scl_out;
      end
   end
 // only master drives scl line  
   assign scl = (scl_reg) ? 1'bz : 1'b0;
   // sda are with pull-up resistors and becomes high when not driven
   // "into" signal asserted when sdat into master
   assign into = (data_phase && cmd_reg==RD_CMD && bit_reg<8) ||
                 (data_phase && cmd_reg==WR_CMD && bit_reg==8);

   assign sda = (into || sda_reg) ? 1'bz : 1'b0;
 // output
   assign dout = rx_reg[8:1];
   assign ack  = rx_reg[0];// obtained from slave in write 
   assign nack = din[0];// used by master in read operation 

   //****************************************************************
   // registers
   //****************************************************************
   always @(posedge clk or posedge reset)
   begin
      if (reset) begin
         state_reg <= idle;
         c_reg     <= 0;
         bit_reg   <= 0;
         cmd_reg   <= 0;
         tx_reg    <= 0;
         rx_reg    <= 0;
      end
      else begin
         state_reg <= state_next;
         c_reg     <= c_next;
         bit_reg   <= bit_next;
         cmd_reg   <= cmd_next;
         tx_reg    <= tx_next;
         rx_reg    <= rx_next;
      end
   end

   assign qutr = dvsr;
   assign half = {qutr[14:0],1'b0};

   //****************************************************************
   // next state logic
   //****************************************************************
   always @(*)
   begin
      state_next = state_reg;
      c_next = c_reg + 1;
      bit_next = bit_reg;
      tx_next = tx_reg;
      rx_next = rx_reg;
      cmd_next = cmd_reg;

      done_tick_i = 0;
      ready_i = 0;

      scl_out = 1'b1;
      sda_out = 1'b1;
      data_phase = 0;

      case(state_reg)

      idle: begin
         ready_i = 1'b1;
         if (wr_i2c && cmd==START_CMD) begin
            state_next = start1;
            c_next = 0;
         end
      end

      start1: begin
         sda_out = 1'b0;
         if (c_reg==half) begin
            c_next = 0;
            state_next = start2;
         end
      end

      start2: begin
         sda_out = 1'b0;
         scl_out = 1'b0;
         if (c_reg==qutr) begin
            c_next = 0;
            state_next = hold;
         end
      end

      hold: begin
         ready_i = 1'b1;
         sda_out = 1'b0;
         scl_out = 1'b0;

         if (wr_i2c) begin
            cmd_next = cmd;
            c_next = 0;

            case(cmd)
               RESTART_CMD, START_CMD: state_next = restart;
               STOP_CMD: state_next = stop1;

               default: begin
                  bit_next = 0;
                  state_next = data1;
                  tx_next = {din,nack};
               end
            endcase
         end
      end

      data1: begin
         sda_out = tx_reg[8];
         scl_out = 0;
         data_phase = 1;
         if (c_reg==qutr) begin
            c_next = 0;
            state_next = data2;
         end
      end

      data2: begin
         sda_out = tx_reg[8];
         data_phase = 1;
         if (c_reg==qutr) begin
            c_next = 0;
            state_next = data3;
            rx_next = {rx_reg[7:0], sda};
         end
      end

      data3: begin
         sda_out = tx_reg[8];
         data_phase = 1;
         if (c_reg==qutr) begin
            c_next = 0;
            state_next = data4;
         end
      end

      data4: begin
         sda_out = tx_reg[8];
         scl_out = 0;
         data_phase = 1;

         if (c_reg==qutr) begin
            c_next = 0;

            if (bit_reg==8) begin
               state_next = data_end;
               done_tick_i = 1'b1;
            end
            else begin
               tx_next = {tx_reg[7:0],1'b0};
               bit_next = bit_reg + 1;
               state_next = data1;
            end
         end
      end

      data_end: begin
         sda_out = 0;
         scl_out = 0;
         if (c_reg==qutr) begin
            c_next = 0;
            state_next = hold;
         end
      end

      restart: begin
         if (c_reg==half) begin
            c_next = 0;
            state_next = start1;
         end
      end

      stop1: begin
         sda_out = 0;
         if (c_reg==half) begin
            c_next = 0;
            state_next = stop2;
         end
      end

      stop2: begin
         if (c_reg==half)
            state_next = idle;
      end

      endcase
   end

   assign done_tick = done_tick_i;
   assign ready = ready_i;

endmodule