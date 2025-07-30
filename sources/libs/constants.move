module aptos_fusion_plus::constants {

    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::object::{Self, Object};

    // - - - - CONSTANTS - - - -

    const DEFAULT_SAFETY_DEPOSIT_METADATA_ADDRESS: address = @0xa;
    const DEFAULT_SAFETY_DEPOSIT_AMOUNT: u64 = 100_000;

    // Source Chain Timelocks (matching 1inch Fusion+ EVM)
    const SRC_FINALITY_LOCK: u64 = 12;      // 12sec finality lock (no actions allowed)
    const SRC_WITHDRAWAL: u64 = 24;         // 12sec exclusive withdrawal (24-12=12sec)
    const SRC_PUBLIC_WITHDRAWAL: u64 = 120; // 96sec public withdrawal (120-24=96sec) 
    const SRC_CANCELLATION: u64 = 180;      // 60sec resolver cancellation (180-120=60sec)
    const SRC_PUBLIC_CANCELLATION: u64 = 240; // 60sec public cancellation (240-180=60sec)

    // Destination Chain Timelocks (shorter for resolver protection)
    const DST_FINALITY_LOCK: u64 = 12;      // 12sec finality lock (no actions allowed)
    const DST_WITHDRAWAL: u64 = 24;         // 12sec exclusive withdrawal (24-12=12sec)
    const DST_PUBLIC_WITHDRAWAL: u64 = 100; // 76sec public withdrawal (100-24=76sec)
    const DST_CANCELLATION: u64 = 160;      // 60sec resolver cancellation (160-100=60sec)

    // Chain IDs
    const SOURCE_CHAIN_ID: u64 = 1; // Aptos chain ID

    public fun get_safety_deposit_metadata(): Object<Metadata> {
        object::address_to_object(DEFAULT_SAFETY_DEPOSIT_METADATA_ADDRESS)
    }

    public fun get_safety_deposit_amount(): u64 {
        DEFAULT_SAFETY_DEPOSIT_AMOUNT
    }

    // Source Chain Timelock Functions
    public fun get_src_finality_lock(): u64 {
        SRC_FINALITY_LOCK
    }

    public fun get_src_withdrawal(): u64 {
        SRC_WITHDRAWAL
    }

    public fun get_src_public_withdrawal(): u64 {
        SRC_PUBLIC_WITHDRAWAL
    }

    public fun get_src_cancellation(): u64 {
        SRC_CANCELLATION
    }

    public fun get_src_public_cancellation(): u64 {
        SRC_PUBLIC_CANCELLATION
    }

    // Destination Chain Timelock Functions
    public fun get_dst_finality_lock(): u64 {
        DST_FINALITY_LOCK
    }

    public fun get_dst_withdrawal(): u64 {
        DST_WITHDRAWAL
    }

    public fun get_dst_public_withdrawal(): u64 {
        DST_PUBLIC_WITHDRAWAL
    }

    public fun get_dst_cancellation(): u64 {
        DST_CANCELLATION
    }

    // Chain ID Functions
    public fun get_source_chain_id(): u64 {
        SOURCE_CHAIN_ID
    }

    // Legacy functions for backward compatibility (deprecated)
    public fun get_finality_duration(): u64 {
        SRC_WITHDRAWAL
    }

    public fun get_exclusive_duration(): u64 {
        SRC_PUBLIC_WITHDRAWAL - SRC_WITHDRAWAL
    }

    public fun get_private_cancellation_duration(): u64 {
        SRC_CANCELLATION - SRC_PUBLIC_WITHDRAWAL
    }
}
