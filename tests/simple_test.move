#[test_only]
module aptos_fusion_plus::simple_test {
    use std::hash;
    use std::signer;
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
    // Test amounts
    const MINT_AMOUNT: u64 = 100000000; // 100 token
    const ASSET_AMOUNT: u64 = 1000000; // 1 token

    // Add these constants at the top for destination asset/recipient
    const DESTINATION_ASSET: vector<u8> = b"\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11";
    const DESTINATION_RECIPIENT: vector<u8> = b"\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22\x22";

    // Test secrets and hashes
    const TEST_SECRET: vector<u8> = b"my secret";

    // Dutch auction parameters
    const INITIAL_DESTINATION_AMOUNT: u64 = 100200;
    const MIN_DESTINATION_AMOUNT: u64 = 100000;
    const DECAY_PER_SECOND: u64 = 20;

    fun setup_test(): (signer, signer, signer, Object<Metadata>, MintRef, Object<Metadata>, MintRef) {
        timestamp::set_time_has_started_for_testing(
            &account::create_signer_for_test(@aptos_framework)
        );
        let fusion_signer = account::create_account_for_test(@aptos_fusion_plus);

        let account_1 = common::initialize_account_with_fa(@0x201);
        let account_2 = common::initialize_account_with_fa(@0x202);
        let resolver = common::initialize_account_with_fa(@0x203);

        resolver_registry::init_module_for_test();
        resolver_registry::register_resolver(
            &fusion_signer, signer::address_of(&resolver)
        );

        let (metadata, mint_ref) = common::create_test_token(
            &fusion_signer, b"Test Token"
        );

        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&account_1));
        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&account_2));
        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&resolver));

        // Mint safety deposit tokens for resolvers since they need to provide safety deposits
        // The safety deposit token must be at the hardcoded address @0xa
        let (safety_deposit_metadata, safety_deposit_mint_ref) = common::create_test_token(
            &fusion_signer, b"Safety Deposit Token"
        );
        common::mint_fa(&safety_deposit_mint_ref, MINT_AMOUNT, signer::address_of(&resolver));
        
        // Also mint safety deposit tokens to the hardcoded address @0xa for the fusion_order module
        common::mint_fa(&safety_deposit_mint_ref, MINT_AMOUNT, @0xa);

        (account_1, account_2, resolver, metadata, mint_ref, safety_deposit_metadata, safety_deposit_mint_ref)
    }

    #[test]
    fun test_create_fusion_order() {
        let (account_1, _, _, metadata, _, _, _) = setup_test();

        let fusion_order =
            fusion_order::new(
                &account_1,
                metadata,
                ASSET_AMOUNT,
                DESTINATION_ASSET,
                DESTINATION_RECIPIENT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET),
                INITIAL_DESTINATION_AMOUNT,
                MIN_DESTINATION_AMOUNT,
                20
            );

        // Verify initial state
        assert!(
            fusion_order::get_owner(fusion_order) == signer::address_of(&account_1), 0
        );
        assert!(fusion_order::get_source_metadata(fusion_order) == metadata, 0);
        assert!(fusion_order::get_source_amount(fusion_order) == ASSET_AMOUNT, 0);
        assert!(fusion_order::get_chain_id(fusion_order) == CHAIN_ID, 0);
        assert!(fusion_order::get_hash(fusion_order) == hash::sha3_256(TEST_SECRET), 0);

        // Verify Dutch auction parameters
        assert!(fusion_order::get_initial_destination_amount(fusion_order) == INITIAL_DESTINATION_AMOUNT, 0);
        assert!(fusion_order::get_min_destination_amount(fusion_order) == MIN_DESTINATION_AMOUNT, 0);

        // Verify the object exists
        let fusion_order_address = object::object_address(&fusion_order);
        assert!(object::object_exists<FusionOrder>(fusion_order_address) == true, 0);

        // Verify only main asset was transferred to the object (no safety deposit)
        let object_main_balance =
            primary_fungible_store::balance(fusion_order_address, metadata);
        assert!(object_main_balance == ASSET_AMOUNT, 0);

        // Verify NO safety deposit was transferred (user doesn't provide safety deposit)
        let object_safety_deposit_balance =
            primary_fungible_store::balance(
                fusion_order_address,
                constants::get_safety_deposit_metadata()
            );
        assert!(object_safety_deposit_balance == 0, 0);
    }
} 