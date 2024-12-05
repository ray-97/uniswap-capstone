// todo: import stylus stuff + check datatype compatibility
 
struct ArbSwapParams {
  uint160 sqrt_price_x_96;
  uint160 new_sqrt_price_x96;
  uint160 sqrt_price_x96_lower;
  uint160 sqrt_price_x96_upper;
  uint128 liquidity;
  uint24 beta_factor;
}