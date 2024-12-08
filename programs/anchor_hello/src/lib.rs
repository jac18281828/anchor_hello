use anchor_lang::prelude::*;

declare_id!("BkXguRLGNNXbLMrmWUaw2RXsmsHPwYx58a9KVuixPSvX");

#[program]
pub mod anchor_hello {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
