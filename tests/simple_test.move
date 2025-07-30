#[test_only]
module aptos_fusion_plus::simple_test {
    use std::hash;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::fungible_asset::{Self, Metadata, MintRef};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_fusion_plus::fusion_order::{Self, FusionOrder};
    use aptos_fusion_plus::common;
    use aptos_fusion_plus::constants;
    use aptos_fusion_plus::resolver_registry;

    // Test constants
    const CHAIN_ID: u64 = 20;
    const MINT_AMOUNT: u64 = 100000000;
    const ASSET_AMOUNT: u64 = 1000000;
    const DESTINATION_AMOUNT: u64 = 500000;
    const NATIVE_ASSET: vector<u8> = b"";
    const EVM_CONTRACT_ADDRESS: vector<u8> = b"12345678901234567890"; // 20 bytes
    const DESTINATION_RECIPIENT: vector<u8> = b"12345678901234567890"; // 20 bytes
    const TEST_SECRET: vector<u8> = b"my secret";

    #[test]
    fun test_new_fusion_order_functionality() {
        timestamp::set_time_has_started_for_testing(
            &account::create_signer_for_test(@aptos_framework)
        );
        let fusion_signer = account::create_account_for_test(@aptos_fusion_plus);

        let account_1 = common::initialize_account_with_fa(@0x201);

        let (metadata, mint_ref) = common::create_test_token(
            &fusion_signer, b"Test Token"
        );

        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&account_1));

        // Test creating fusion order with new parameters
        let fusion_order = fusion_order::new(
            &account_1,
            metadata,
            ASSET_AMOUNT,
            NATIVE_ASSET,
            DESTINATION_AMOUNT,
            DESTINATION_RECIPIENT,
            CHAIN_ID,
            hash::sha3_256(TEST_SECRET)
        );

        // Verify the new fields work correctly
        assert!(fusion_order::get_source_metadata(fusion_order) == metadata, 0);
        assert!(fusion_order::get_source_amount(fusion_order) == ASSET_AMOUNT, 0);
        assert!(fusion_order::get_destination_asset(fusion_order) == NATIVE_ASSET, 0);
        assert!(fusion_order::get_destination_amount(fusion_order) == DESTINATION_AMOUNT, 0);
        assert!(fusion_order::get_destination_recipient(fusion_order) == DESTINATION_RECIPIENT, 0);
        assert!(fusion_order::get_chain_id(fusion_order) == CHAIN_ID, 0);

        // Test utility functions
        assert!(fusion_order::is_native_asset(&NATIVE_ASSET), 0);
        assert!(fusion_order::is_evm_contract_address(&EVM_CONTRACT_ADDRESS), 0);
        assert!(fusion_order::is_valid_evm_address(&DESTINATION_RECIPIENT), 0);

        // Clean up
        fusion_order::cancel(&account_1, fusion_order);
    }
} 