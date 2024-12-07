// Allow `cargo stylus export-abi` to generate a main function.
#![cfg_attr(all(not(feature = "std"), not(feature = "export-abi")), no_main)]
extern crate alloc;

/// Import items from the SDK. The prelude contains common traits and macros.
// use stylus_sdk::{alloy_primitives::U256, prelude::*};
// use alloy_primitives::Address;

use rust_decimal::prelude::*;
use rust_decimal_macros::dec;
use stylus_sdk::{alloy_primitives::U256, console, prelude::*};
use alloy_primitives::Address;

#[storage]
#[entrypoint]
struct LVRCompute {
    risky_asset: Address, // address of the risky asset, aka x
    numeraire: Address, // address of the numeraire
    trades: U256, // number of trades to date
    price: U256, // last seen asset price
    volatility: U256, // last computed price volatility
    marginal_liq: U256, // last computed marginal liquidity, how much x moves when price moves
    lvrt: U256, // last computed LVR time
    lvr: U256, // accumulated LVR to date
    fees: U256, // fees collected to date
}


pub trait Analytics {
    fn feed_lvr_data(&mut self, price: U256, volatility: U256, marginal_liq: U256) -> U256;

    fn get_lvr(&self) -> U256;

    fn feed_fees(&mut self, fees: U256) -> ();

    fn get_fees(&self) -> U256;

    fn set_asset(&mut self, risky_asset: Address, numeraire: Address) -> ();
}

impl LVRCompute {
    pub fn new(risky_asset: Address, numeraire: Address) -> Self {
        Self {
            risky_asset,
            numeraire,
            trades: U256::from(0),
            price: U256::from(0),
            volatility: U256::from(0),
            marginal_liq: U256::from(0),
            lvrt: U256::from(0),
            lvr: U256::from(0),
            fees: U256::from(0),
        }
    }
}

fn compute_lvr(
    volatilty: U256,
    price: U256,
    marginal_liq: U256,
) -> U256 {
    let volatility_dec = Decimal::from(volatilty);
    let price_dec = Decimal::from(price);
    let marginal_liq_dec = Decimal::from(marginal_liq);
    let variance = volatility_dec * volatility_dec * price_dec * price_dec / Decimal::TWO;
    let lvr = variance * marginal_liq_dec;
    lvr
}

impl Analytics for LVRCompute {
    fn feed_lvr_data(&mut self, price: U256, volatility: U256, marginal_liq: U256) -> U256 {
        let lvr = compute_lvr(volatility, price, marginal_liq);
        self.price = price;
        self.volatility = volatility;
        self.marginal_liq = marginal_liq;
        self.lvr = self.lvr + lvr;
        self.trades = self.trades + U256::from(1);
        self.lvrt = lvr;
        lvr
    }

    fn feed_fees(&mut self, fees: U256) {
        self.fees = self.fees + fees;
    }

    fn get_fees(&self) -> U256 {
        self.fees
    }

    fn get_lvr(&self) -> U256 {
        self.lvr
    }

    fn set_asset(&mut self, risky_asset: Address, numeraire: Address) {
        self.risky_asset = risky_asset;
        self.numeraire = numeraire;
    }
    
}

