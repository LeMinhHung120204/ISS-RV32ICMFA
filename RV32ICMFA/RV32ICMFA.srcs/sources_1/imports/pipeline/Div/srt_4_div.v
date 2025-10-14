`timescale 1ns/1ps

module srt_4_div#(
	parameter DW = 32
)(
	input 				clk,
	input 				rst_n,

	input				start,

	input[DW-1:0]		dividend,
	input[DW-1:0] 		divisor,
		

	output[DW-1:0] 		quotient,
	output[DW-1:0] 		reminder,
	output				mulfinish,
	output				diverror
);
	localparam	IDLE = 2'b00 , DIV = 2'b01 , FINISH = 2'b10 , ERROR = 2'b11 ;

	wire[DW/2-1:0] 	iterations;
	wire[DW/2-1:0] 	recovery;
	wire[DW+32:0]	reminder_temp;
	wire[DW-1:0] 	q_out_fix;
	wire[DW-1:0] 	q_out_1;
	wire[DW+2:0] 	divisor_star;
	wire[DW+3:0] 	w_reg_fix;
	wire[DW+3:0]	w_0_4; 
	wire[DW+3:0] 	divisor_real;
	wire[DW+3:0] 	divisor_2_real;
	wire[DW+3:0] 	divisor_neg;
	wire[DW+3:0] 	divisor_2_neg;
	wire[DW+3:0]	w_next;
	wire[DW+3:0] 	w_next_temp;
	wire[DW+5:0] 	dividend_star;
	wire 			w_reg_unsign;
	wire 			dividend_eq_0_t;
	wire 			divisor_eq_0_t;
	
	wire[1:0] 			q_table;
	wire[2:0]	 		q_in; 
	wire[3:0] 			divisor_index;
	wire signed[6:0]	dividend_index;
	
	reg[DW/2-1:0]	iterations_temp, iterations_reg, recovery_temp, recovery_reg;	
	reg[DW/4:0]	   	counter, counter_next;
	reg[DW+3:0] 	w_reg, w_temp;
	reg[DW+3:0] 	divisor_reg, divisor_temp;
	reg[1:0]		state, state_next;
	
	assign w_0_4 			= dividend_star[DW+3:0];

	assign divisor_real 	= divisor_reg;
	assign divisor_2_real	= divisor_real << 1;
	assign divisor_neg  	= ~divisor_real + 1'b1;
	assign divisor_2_neg 	= divisor_neg << 1;

	assign dividend_index 	= w_reg[DW+3:DW-3];
	assign divisor_index  	= divisor_reg[DW:DW-3];

	assign dividend_eq_0_t	= (dividend == 0);
	assign divisor_eq_0_t 	= (divisor == 0);	

	assign w_next 			= w_next_temp << 2;
	assign q_in   			= {dividend_index[6] , q_table};

	assign w_next_temp 		= 	({dividend_index[6] , q_table} == 3'b001) ? divisor_neg + w_reg :
								({dividend_index[6] , q_table} == 3'b010) ? w_reg + divisor_2_neg :
								({dividend_index[6] , q_table} == 3'b101) ? w_reg + divisor_real :
								({dividend_index[6] , q_table} == 3'b110) ? w_reg + divisor_2_real :
								(q_table ==2'b00) ?  w_reg : 12'b0 ;

	pre_processing u1(
		.start(start),
		.dividend(dividend),
		.divisor(divisor),
		.iterations(iterations),
		.divisor_star(divisor_star),
		.dividend_star(dividend_star),
		.recovery(recovery)
	);

	radix4_table u2(
		.dividend_index(dividend_index),
		.divisor_index(divisor_index),
		.q_table(q_table)
	);

	on_the_fly_conversion u3(
		.clk(clk),
		.rst_n(rst_n),
		.q_in(q_in),
		.state_in(state),
		.q_out(q_out_1)
	);

	always @(posedge clk , negedge rst_n ) begin
		if (!rst_n) begin
			state 			<= IDLE;
			divisor_reg 	<= 0;
			counter 		<= 0;
			w_reg   		<= 0;
			iterations_reg	<= 0;
			recovery_reg 	<= 0;
		end
		else begin
			state   		<= state_next;
			divisor_reg 	<= divisor_temp;
			counter 		<= counter_next;
			w_reg   		<= w_temp ;
			iterations_reg	<= iterations_temp;
			recovery_reg 	<= recovery_temp;
		end
	end


	always @(*) begin
		case(state)
			IDLE : begin
				if (start & ~dividend_eq_0_t & ~divisor_eq_0_t) begin
					state_next 		= DIV;
					divisor_temp 	= {divisor_star , 1'b0};
					w_temp 			= w_0_4;
					counter_next 	= 0;
					iterations_temp	= iterations;
					recovery_temp 	= recovery;

				end 
				else if (start & dividend_eq_0_t) begin
					state_next = FINISH;
					divisor_temp 	= 0;
					w_temp 			= 0;
					counter_next 	= 0;
					iterations_temp	= 0;
					recovery_temp 	= 0;
				end 
				else if (start & divisor_eq_0_t) begin
					state_next 		= ERROR;
					divisor_temp 	= 0;
					w_temp 			= 0;
					counter_next 	= 0;
					iterations_temp	= 0;
					recovery_temp 	= 0;
				end 
				else begin
					state_next 		= IDLE;
					divisor_temp 	= 0;
					w_temp 			= 0;
					counter_next 	= 0;
					iterations_temp	= 0;
					recovery_temp 	= 0;
				end
			end
			DIV: begin
				if(counter != iterations_reg - 1 ) begin
					state_next 		= DIV;
					w_temp 			= w_next;
					divisor_temp 	= divisor_reg;
					counter_next 	= counter + 1'b1;
					iterations_temp	= iterations_reg;
					recovery_temp 	= recovery_reg;
					
				end
				else begin
						state_next 		= FINISH;
						w_temp 			= w_next_temp;
						divisor_temp 	= divisor_reg;
						counter_next 	= 0;
						iterations_temp	= iterations_reg;
						recovery_temp 	= recovery_reg;
					end
				end
			
			FINISH: begin
				state_next 		= IDLE;
				divisor_temp 	= 0;
				counter_next 	= 0;
				w_temp   		= 0;
				iterations_temp	= 0;
				recovery_temp 	= 0;
			end
			ERROR: begin
				state_next 		= IDLE;
				divisor_temp 	= 0;
				counter_next 	= 0;
				w_temp   		= 0;
				iterations_temp	= 0;
				recovery_temp 	= 0;
			end
		endcase
	end

	assign w_reg_unsign		= (w_reg[DW+3] == 1);
	assign w_reg_fix 		= w_reg_unsign ? w_reg + divisor_real	: w_reg;
	assign q_out_fix 		= w_reg_unsign ? q_out_1 - 1 			: q_out_1;

	// output
	assign reminder_temp	= ({28'b0 , w_reg_fix} << recovery_reg);
	assign reminder 		= reminder_temp[DW+32:DW+1];
	assign quotient			= q_out_fix;
	assign diverror  		= (state == ERROR) ;
	assign mulfinish 		= (state == FINISH) ;

endmodule