// Allow `cargo stylus export-abi` to generate a main function.
#![cfg_attr(all(not(feature = "std"), not(feature = "export-abi")), no_main)]
extern crate alloc;

/// Import items from the SDK. The prelude contains common traits and macros.
use stylus_sdk::{
    prelude::entrypoint,
    stylus_proc::{public, sol_storage, SolidityError},
};

use alloy_primitives::{U160, U256};
use alloy_sol_types::sol;

sol! {
    /// Indicates a custom error.
    #[derive(Debug)]
    #[allow(missing_docs)]
    error CurveCustomError();
}

#[derive(SolidityError, Debug)]
pub enum Error {
    /// Indicates a custom error.
    CustomError(CurveCustomError),
}

sol_storage! {
    #[entrypoint]
    struct Compute { }
}

/// Interface of an [`Compute`] contract.
///
/// NOTE: The contract's interface can be modified in any way.
pub trait IAnalytics {
    fn compute_lvr(
        &self,
        volatility: U256,
        marginal_liq: U256,
    ) -> Result<U256, Error>;
}

/// Declare that [`Compute`] is a contract
/// with the following external methods.
#[public]
impl IAnalytics for Compute {
    fn compute_lvr(
        &self,
        volatility: U256, // change in price
        marginal_liq: U256, // % change in liquidity of risky asset
    ) -> Result<U256, Error> {
        let volatility = volatility.to::<U256>();
        let volatility_sq = mul_div(volatility, volatility, U256::from(1))?;
        let variance = mul_div(volatility_sq, U256::from(1), U256::from(2))?;
        let lvr = mul_div(variance, marginal_liq, U256::from(1))?;
        Ok(lvr)
  }
}


// source for helper: https://github.com/OpenZeppelin/uniswap-stylus-curve-template/blob/main/src/lib.rs

/// Returns `a * b / c` and if the result had carry.
pub fn _mul_div(a: U256, b: U256, mut denom_and_rem: U256) -> Result<(U256, bool), Error> {
  if denom_and_rem == U256::ZERO {
      return Err(Error::CustomError(CurveCustomError{}));
  }

  let mut mul_and_quo = a.widening_mul::<256, 4, 512, 8>(b);

  unsafe {
      ruint::algorithms::div(mul_and_quo.as_limbs_mut(), denom_and_rem.as_limbs_mut());
  }

  let limbs = mul_and_quo.into_limbs();
  if limbs[4..] != [0_u64; 4] {
    return Err(Error::CustomError(CurveCustomError{}));
  }

  let has_carry = denom_and_rem != U256::ZERO;

  Ok((U256::from_limbs_slice(&limbs[0..4]), has_carry))
}

/// Returns `a * b / c`, rounding down.
pub fn mul_div(a: U256, b: U256, denom: U256) -> Result<U256, Error> {
  Ok(_mul_div(a, b, denom)?.0)
}