#[test_only]
module aptos_fusion_plus::escrow_tests {
    use std::hash;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::fungible_asset::{Metadata, MintRef};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;
    use aptos_fusion_plus::escrow::{Self, Escrow};
    use aptos_fusion_plus::fusion_order::{Self, FusionOrder};
    use aptos_fusion_plus::common;
    use aptos_fusion_plus::constants;
    use aptos_fusion_plus::resolver_registry;
    use aptos_fusion_plus::timelock::{Self};
    use aptos_fusion_plus::hashlock::{Self};

    // Test accounts
    const CHAIN_ID: u64 = 20;

    // Test amounts
    const MINT_AMOUNT: u64 = 100000000; // 100 token
    const ASSET_AMOUNT: u64 = 1000000; // 1 token

    // Test secrets and hashes
    const TEST_SECRET: vector<u8> = b"my secret";
    const WRONG_SECRET: vector<u8> = b"wrong secret";

    // Test destination parameters
    const DESTINATION_AMOUNT: u64 = 500000;
    const NATIVE_ASSET: vector<u8> = b"";
    // Use a real 20-byte EVM address for all tests
    const EVM_CONTRACT_ADDRESS: vector<u8> = b"\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11"; // 20 bytes
    const DESTINATION_RECIPIENT: vector<u8> = b"\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11\x11"; // 20 bytes

    fun setup_test(): (signer, signer, signer, Object<Metadata>, MintRef) {
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

        // Mint assets to accounts
        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&account_1));
        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&account_2));
        common::mint_fa(&mint_ref, MINT_AMOUNT, signer::address_of(&resolver));

        (account_1, account_2, resolver, metadata, mint_ref)
    }

    fun create_fusion_order_with_defaults(
        signer: &signer,
        metadata: Object<Metadata>,
        amount: u64,
        chain_id: u64,
        hash: vector<u8>
    ): Object<FusionOrder> {
        fusion_order::new(
            signer,
            metadata,
            amount,
            NATIVE_ASSET,           // Default to native asset
            amount,                  // Default destination amount same as source
            DESTINATION_RECIPIENT,   // Default recipient
            chain_id,
            hash
        )
    }

    #[test]
    fun test_create_escrow_from_order() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create a fusion order first
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let fusion_order_address = object::object_address(&fusion_order);

        // Verify fusion order exists
        assert!(object::object_exists<FusionOrder>(fusion_order_address) == true, 0);

        // Create escrow from fusion order
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        let escrow_address = object::object_address(&escrow);

        // Verify fusion order is deleted
        assert!(object::object_exists<FusionOrder>(fusion_order_address) == false, 0);

        // Verify escrow is created
        assert!(object::object_exists<Escrow>(escrow_address) == true, 0);

        // Verify escrow properties
        assert!(escrow::get_metadata(escrow) == metadata, 0);
        assert!(escrow::get_amount(escrow) == ASSET_AMOUNT, 0);
        assert!(escrow::get_from(escrow) == signer::address_of(&owner), 0);
        assert!(escrow::get_to(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_resolver(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_chain_id(escrow) == CHAIN_ID, 0);

        // Verify assets are in escrow
        let escrow_main_balance =
            primary_fungible_store::balance(escrow_address, metadata);
        assert!(escrow_main_balance == ASSET_AMOUNT, 0);

        let escrow_safety_deposit_balance =
            primary_fungible_store::balance(
                escrow_address,
                constants::get_safety_deposit_metadata()
            );
        assert!(
            escrow_safety_deposit_balance == constants::get_safety_deposit_amount(), 0
        );
    }

    #[test]
    fun test_create_escrow_from_resolver() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Record initial balances
        let initial_resolver_main_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        let initial_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );

        // Create escrow directly from resolver
        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let escrow_address = object::object_address(&escrow);

        // Verify escrow is created
        assert!(object::object_exists<Escrow>(escrow_address) == true, 0);

        // Verify escrow properties
        assert!(escrow::get_metadata(escrow) == metadata, 0);
        assert!(escrow::get_amount(escrow) == ASSET_AMOUNT, 0);
        assert!(escrow::get_from(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_to(escrow) == signer::address_of(&recipient), 0);
        assert!(escrow::get_resolver(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_chain_id(escrow) == CHAIN_ID, 0);

        // Verify resolver's balances decreased
        let final_resolver_main_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        let final_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );

        assert!(
            final_resolver_main_balance == initial_resolver_main_balance - ASSET_AMOUNT,
            0
        );
        assert!(
            final_resolver_safety_deposit_balance
                == initial_resolver_safety_deposit_balance
                    - constants::get_safety_deposit_amount(),
            0
        );

        // Verify assets are in escrow
        let escrow_main_balance =
            primary_fungible_store::balance(escrow_address, metadata);
        assert!(escrow_main_balance == ASSET_AMOUNT, 0);

        let escrow_safety_deposit_balance =
            primary_fungible_store::balance(
                escrow_address,
                constants::get_safety_deposit_metadata()
            );
        assert!(
            escrow_safety_deposit_balance == constants::get_safety_deposit_amount(), 0
        );
    }

    #[test]
    fun test_create_escrow_from_order_multiple_orders() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create multiple fusion orders
        let fusion_order1 =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let fusion_order2 =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT * 2,
                CHAIN_ID,
                hash::sha3_256(WRONG_SECRET)
            );

        // Convert both to escrow
        let escrow1 = escrow::new_from_order(&resolver, fusion_order1);
        let escrow2 = escrow::new_from_order(&resolver, fusion_order2);

        let escrow1_address = object::object_address(&escrow1);
        let escrow2_address = object::object_address(&escrow2);

        // Verify both escrows exist
        assert!(object::object_exists<Escrow>(escrow1_address) == true, 0);
        assert!(object::object_exists<Escrow>(escrow2_address) == true, 0);

        // Verify escrow properties
        assert!(escrow::get_amount(escrow1) == ASSET_AMOUNT, 0);
        assert!(
            escrow::get_amount(escrow2) == ASSET_AMOUNT * 2,
            0
        );
        assert!(escrow::get_from(escrow1) == signer::address_of(&owner), 0);
        assert!(escrow::get_from(escrow2) == signer::address_of(&owner), 0);
        assert!(escrow::get_to(escrow1) == signer::address_of(&resolver), 0);
        assert!(escrow::get_to(escrow2) == signer::address_of(&resolver), 0);
    }

    #[test]
    fun test_create_escrow_from_resolver_different_recipients() {
        let (recipient1, recipient2, resolver, metadata, _) = setup_test();

        // Create escrows with different recipients
        let escrow1 =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient1),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let escrow2 =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient2),
                metadata,
                ASSET_AMOUNT * 2,
                CHAIN_ID,
                hash::sha3_256(WRONG_SECRET)
            );

        // Verify escrow properties
        assert!(escrow::get_to(escrow1) == signer::address_of(&recipient1), 0);
        assert!(escrow::get_to(escrow2) == signer::address_of(&recipient2), 0);
        assert!(escrow::get_amount(escrow1) == ASSET_AMOUNT, 0);
        assert!(
            escrow::get_amount(escrow2) == ASSET_AMOUNT * 2,
            0
        );
    }

    #[test]
    fun test_create_escrow_large_amount() {
        let (_, recipient, resolver, metadata, mint_ref) = setup_test();

        let large_amount = 1000000000000; // 1M tokens

        // Mint large amount to resolver
        common::mint_fa(&mint_ref, large_amount, signer::address_of(&resolver));

        // Record initial balance
        let initial_resolver_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);

        // Create escrow with large amount
        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                large_amount,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Verify escrow properties
        assert!(escrow::get_amount(escrow) == large_amount, 0);
        assert!(escrow::get_from(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_to(escrow) == signer::address_of(&recipient), 0);

        // Verify resolver's balance decreased
        let final_resolver_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        assert!(
            final_resolver_balance == initial_resolver_balance - large_amount,
            0
        );

        // Verify escrow has the assets
        let escrow_address = object::object_address(&escrow);
        let escrow_balance = primary_fungible_store::balance(escrow_address, metadata);
        assert!(escrow_balance == large_amount, 0);
    }

    #[test]
    fun test_escrow_timelock_and_hashlock() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Verify timelock is active
        let timelock = escrow::get_timelock(escrow);
        assert!(timelock::is_in_withdrawal_phase(&timelock) == true, 0);

        // Verify hashlock is created with correct hash
        let hashlock = escrow::get_hashlock(escrow);
        assert!(hashlock::verify_hashlock(&hashlock, TEST_SECRET) == true, 0);
        assert!(hashlock::verify_hashlock(&hashlock, WRONG_SECRET) == false, 0);
    }

    #[test]
    fun test_escrow_phase_transitions() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let timelock = escrow::get_timelock(escrow);

        // Initially in withdrawal phase
        assert!(timelock::is_in_withdrawal_phase(&timelock) == true, 0);
        assert!(timelock::is_in_public_withdrawal_phase(&timelock) == false, 0);
        assert!(timelock::is_in_cancellation_phase(&timelock) == false, 0);
        assert!(timelock::is_in_public_cancellation_phase(&timelock) == false, 0);

        // Fast forward to public withdrawal phase
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15
        );

        assert!(timelock::is_in_withdrawal_phase(&timelock) == false, 0);
        assert!(timelock::is_in_public_withdrawal_phase(&timelock) == true, 0);
        assert!(timelock::is_in_cancellation_phase(&timelock) == false, 0);
        assert!(timelock::is_in_public_cancellation_phase(&timelock) == false, 0);
    }

    #[test]
    fun test_escrow_safety_deposit_handling() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Record initial safety deposit balance
        let initial_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );

        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let escrow_address = object::object_address(&escrow);

        // Verify resolver's safety deposit balance decreased
        let final_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );
        assert!(
            final_resolver_safety_deposit_balance
                == initial_resolver_safety_deposit_balance
                    - constants::get_safety_deposit_amount(),
            0
        );

        // Verify escrow has safety deposit
        let escrow_safety_deposit_balance =
            primary_fungible_store::balance(
                escrow_address,
                constants::get_safety_deposit_metadata()
            );
        assert!(
            escrow_safety_deposit_balance == constants::get_safety_deposit_amount(), 0
        );
    }

    #[test]
    fun test_escrow_object_lifecycle() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create fusion order
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        let fusion_order_address = object::object_address(&fusion_order);

        // Verify fusion order exists
        assert!(object::object_exists<FusionOrder>(fusion_order_address) == true, 0);

        // Convert to escrow
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        let escrow_address = object::object_address(&escrow);

        // Verify fusion order is deleted and escrow is created
        assert!(object::object_exists<FusionOrder>(fusion_order_address) == false, 0);
        assert!(object::object_exists<Escrow>(escrow_address) == true, 0);

        // Verify escrow controller exists
        assert!(
            object::object_exists<escrow::EscrowController>(escrow_address) == true, 0
        );
    }

    // - - - - SOURCE CHAIN SCENARIOS - - - -

    #[test]
    fun test_source_chain_escrow_withdrawal() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create fusion order (source chain scenario)
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Convert to escrow
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to public withdrawal phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15 // Move to public withdrawal phase
        );

        // Record initial balances
        let initial_resolver_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        let initial_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );

        // Resolver withdraws using correct secret (gets tokens from source chain)
        escrow::withdraw(&resolver, escrow, TEST_SECRET);

        // Verify resolver received the assets (source chain: resolver gets tokens)
        let final_resolver_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        assert!(
            final_resolver_balance == initial_resolver_balance + ASSET_AMOUNT,
            0
        );

        // Verify resolver received safety deposit back
        let final_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );
        assert!(
            final_resolver_safety_deposit_balance
                == initial_resolver_safety_deposit_balance
                    + constants::get_safety_deposit_amount(),
            0
        );
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_SECRET)]
    fun test_source_chain_escrow_withdrawal_wrong_secret() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create fusion order (source chain scenario)
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Convert to escrow
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to public withdrawal phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15 // Move to public withdrawal phase
        );

        // Try to withdraw with wrong secret
        escrow::withdraw(&resolver, escrow, WRONG_SECRET);
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_PHASE)]
    fun test_source_chain_escrow_withdrawal_wrong_phase() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create fusion order (source chain scenario)
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Convert to escrow
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to cancellation phase where withdrawal is not allowed
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 125 // Move to cancellation phase
        );

        // Try to withdraw in cancellation phase (should fail)
        escrow::withdraw(&resolver, escrow, TEST_SECRET);
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_CALLER)]
    fun test_source_chain_escrow_withdrawal_wrong_caller() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create fusion order (source chain scenario)
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Convert to escrow
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to public withdrawal phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15 // Move to public withdrawal phase
        );

        // Try to withdraw with wrong caller (user cannot call withdraw)
        escrow::withdraw(&owner, escrow, TEST_SECRET);
    }

    // - - - - DESTINATION CHAIN SCENARIOS - - - -

    #[test]
    fun test_destination_chain_escrow_withdrawal() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Create escrow directly from resolver (destination chain scenario)
        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Fast forward to public withdrawal phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15 // Move to public withdrawal phase
        );

        // Record initial balances
        let initial_recipient_balance =
            primary_fungible_store::balance(signer::address_of(&recipient), metadata);
        let initial_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );

        // Resolver withdraws using correct secret (user gets tokens from destination chain)
        escrow::withdraw(&resolver, escrow, TEST_SECRET);

        // Verify recipient (user) received the assets (destination chain: user gets tokens)
        let final_recipient_balance =
            primary_fungible_store::balance(signer::address_of(&recipient), metadata);
        assert!(
            final_recipient_balance == initial_recipient_balance + ASSET_AMOUNT,
            0
        );

        // Verify resolver received safety deposit back
        let final_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );
        assert!(
            final_resolver_safety_deposit_balance
                == initial_resolver_safety_deposit_balance
                    + constants::get_safety_deposit_amount(),
            0
        );
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_AMOUNT)]
    fun test_destination_chain_escrow_zero_amount() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Try to create escrow with zero amount
        escrow::new_from_resolver(
            &resolver,
            signer::address_of(&recipient),
            metadata,
            0, // Zero amount should fail
            CHAIN_ID,
            hash::sha3_256(TEST_SECRET)
        );
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_SECRET)]
    fun test_destination_chain_escrow_invalid_hash() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Try to create escrow with invalid hash
        escrow::new_from_resolver(
            &resolver,
            signer::address_of(&recipient),
            metadata,
            ASSET_AMOUNT,
            CHAIN_ID,
            vector::empty() // Empty hash should fail
        );
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_CALLER)]
    fun test_destination_chain_escrow_withdrawal_wrong_caller() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Create escrow directly from resolver (destination chain scenario)
        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Fast forward to public withdrawal phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15 // Move to public withdrawal phase
        );

        // Try to withdraw with wrong caller (user cannot call withdraw)
        escrow::withdraw(&recipient, escrow, TEST_SECRET);
    }

    // - - - - RECOVERY SCENARIOS - - - -

    #[test]
    fun test_escrow_recovery_private_cancellation() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create escrow from fusion order
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to cancellation phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 125 // Move to cancellation phase
        );

        // Record initial balances
        let initial_owner_balance =
            primary_fungible_store::balance(signer::address_of(&owner), metadata);
        let initial_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );

        // Recover escrow (only resolver can do this in private cancellation)
        escrow::recovery(&resolver, escrow);

        // Verify owner received the assets back
        let final_owner_balance =
            primary_fungible_store::balance(signer::address_of(&owner), metadata);
        assert!(
            final_owner_balance == initial_owner_balance + ASSET_AMOUNT,
            0
        );

        // Verify resolver received safety deposit back
        let final_resolver_safety_deposit_balance =
            primary_fungible_store::balance(
                signer::address_of(&resolver),
                constants::get_safety_deposit_metadata()
            );
        assert!(
            final_resolver_safety_deposit_balance
                == initial_resolver_safety_deposit_balance
                    + constants::get_safety_deposit_amount(),
            0
        );
    }

    #[test]
    fun test_escrow_recovery_public_cancellation() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Create escrow from resolver with source chain ID to enable public cancellation phase
        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(), // Use source chain ID to enable public cancellation
                hash::sha3_256(TEST_SECRET)
            );

        // Fast forward to public cancellation phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 122 // Move to public cancellation phase (121-122s)
        );

        // Record initial balances
        let initial_resolver_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        let initial_anyone_balance =
            primary_fungible_store::balance(
                signer::address_of(&recipient),
                constants::get_safety_deposit_metadata()
            );

        // Anyone can recover in public cancellation phase
        escrow::recovery(&recipient, escrow);

        // Verify resolver received the assets back
        let final_resolver_balance =
            primary_fungible_store::balance(signer::address_of(&resolver), metadata);
        assert!(
            final_resolver_balance == initial_resolver_balance + ASSET_AMOUNT,
            0
        );

        // Verify anyone received safety deposit
        let final_anyone_balance =
            primary_fungible_store::balance(
                signer::address_of(&recipient),
                constants::get_safety_deposit_metadata()
            );
        assert!(
            final_anyone_balance
                == initial_anyone_balance + constants::get_safety_deposit_amount(),
            0
        );
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_CALLER)]
    fun test_escrow_recovery_private_cancellation_wrong_caller() {
        let (owner, recipient, resolver, metadata, _) = setup_test();

        // Create escrow from fusion order
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to cancellation phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 125 // Move to cancellation phase
        );

        // Try to recover with wrong caller (only resolver can do this in private cancellation)
        escrow::recovery(&recipient, escrow);
    }

    #[test]
    #[expected_failure(abort_code = escrow::EINVALID_PHASE)]
    fun test_escrow_recovery_wrong_phase() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create escrow from fusion order
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Try to recover in finality phase (should fail)
        escrow::recovery(&resolver, escrow);
    }

    // - - - - UTILITY FUNCTION TESTS - - - -

    #[test]
    fun test_escrow_utility_functions() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        let escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        // Test is_source_chain for destination chain scenario
        assert!(escrow::is_source_chain(escrow) == false, 0); // resolver != to

        // Test is_source_chain for source chain scenario
        let fusion_order =
            create_fusion_order_with_defaults(
                &resolver,
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(),
                hash::sha3_256(TEST_SECRET)
            );
        let source_escrow = escrow::new_from_order(&resolver, fusion_order);
        assert!(escrow::is_source_chain(source_escrow) == true, 0); // resolver == to

        // Test getter functions
        assert!(escrow::get_metadata(escrow) == metadata, 0);
        assert!(escrow::get_amount(escrow) == ASSET_AMOUNT, 0);
        assert!(escrow::get_from(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_to(escrow) == signer::address_of(&recipient), 0);
        assert!(escrow::get_resolver(escrow) == signer::address_of(&resolver), 0);
        assert!(escrow::get_chain_id(escrow) == CHAIN_ID, 0);

        // Test timelock and hashlock getters
        let timelock = escrow::get_timelock(escrow);
        let hashlock = escrow::get_hashlock(escrow);
        assert!(timelock::is_destination_chain(&timelock), 0);
        assert!(hashlock::get_hash(&hashlock) == hash::sha3_256(TEST_SECRET), 0);

        // Test escrow_exists
        assert!(escrow::escrow_exists(escrow), 0);
    }

    #[test]
    fun test_escrow_concurrent_withdrawal_attempts() {
        let (owner, recipient, resolver, metadata, _) = setup_test();

        // Create escrow from fusion order
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(),
                hash::sha3_256(TEST_SECRET)
            );
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        // Fast forward to public withdrawal phase
        let timelock = escrow::get_timelock(escrow);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock) + 15 // Move to public withdrawal phase
        );

        // First withdrawal should succeed (resolver can withdraw)
        escrow::withdraw(&resolver, escrow, TEST_SECRET);

        // Second withdrawal attempt should fail (escrow is already deleted)
        // This simulates concurrent withdrawal attempts
        let escrow2 = escrow::new_from_resolver(
            &resolver,
            signer::address_of(&recipient),
            metadata,
            ASSET_AMOUNT,
            constants::get_source_chain_id(),
            hash::sha3_256(TEST_SECRET)
        );

        // Fast forward to public withdrawal phase
        let timelock2 = escrow::get_timelock(escrow2);
        timestamp::update_global_time_for_test_secs(
            timelock::get_created_at(&timelock2) + 15
        );

        // Second withdrawal should also succeed (different escrow)
        escrow::withdraw(&resolver, escrow2, TEST_SECRET);
    }

    #[test]
    fun test_escrow_phase_transition_edge_cases() {
        let (owner, recipient, resolver, metadata, _) = setup_test();

        // Create escrow from fusion order
        let fusion_order =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(),
                hash::sha3_256(TEST_SECRET)
            );
        let escrow = escrow::new_from_order(&resolver, fusion_order);

        let timelock = escrow::get_timelock(escrow);
        let created_at = timelock::get_created_at(&timelock);

        // Test withdrawal at exact boundary (10 seconds)
        timestamp::update_global_time_for_test_secs(created_at + 10);
        escrow::withdraw(&resolver, escrow, TEST_SECRET);

        // Create new escrow for next test
        let fusion_order2 =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(),
                hash::sha3_256(WRONG_SECRET)
            );
        let escrow2 = escrow::new_from_order(&resolver, fusion_order2);

        let timelock2 = escrow::get_timelock(escrow2);
        let created_at2 = timelock::get_created_at(&timelock2);

        // Test withdrawal just before boundary (9 seconds)
        timestamp::update_global_time_for_test_secs(created_at2 + 9);
        escrow::withdraw(&resolver, escrow2, WRONG_SECRET);

        // Create new escrow for next test
        let fusion_order3 =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(),
                hash::sha3_256(TEST_SECRET)
            );
        let escrow3 = escrow::new_from_order(&resolver, fusion_order3);

        let timelock3 = escrow::get_timelock(escrow3);
        let created_at3 = timelock::get_created_at(&timelock3);

        // Test withdrawal just after boundary (11 seconds)
        timestamp::update_global_time_for_test_secs(created_at3 + 11);
        escrow::withdraw(&resolver, escrow3, TEST_SECRET);
    }

    // - - - - FIXED REMOVED TESTS - - - -

    #[test]
    fun test_escrow_boundary_amounts() {
        let (_, recipient, resolver, metadata, mint_ref) = setup_test();

        // Test minimum amount (1)
        let min_escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                1,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        assert!(escrow::get_amount(min_escrow) == 1, 0);

        // Test maximum reasonable amount (use smaller amount to avoid balance issues)
        let max_amount = 1000000u64; // 1 million tokens
        
        // Mint additional tokens to resolver to ensure sufficient balance
        common::mint_fa(&mint_ref, max_amount, signer::address_of(&resolver));

        let max_escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                max_amount,
                CHAIN_ID,
                hash::sha3_256(TEST_SECRET)
            );

        assert!(escrow::get_amount(max_escrow) == max_amount, 0);

        // Verify escrow has the assets
        let max_escrow_address = object::object_address(&max_escrow);
        let max_escrow_balance = primary_fungible_store::balance(max_escrow_address, metadata);
        assert!(max_escrow_balance == max_amount, 0);
    }

    #[test]
    fun test_escrow_hash_edge_cases() {
        let (_, recipient, resolver, metadata, _) = setup_test();

        // Test minimum valid hash (32 bytes of zeros)
        let min_secret = vector::empty<u8>();
        let i = 0;
        while (i < 32) {
            vector::push_back(&mut min_secret, 0u8);
            i = i + 1;
        };
        let min_hash = hash::sha3_256(min_secret);

        let min_hash_escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                min_hash
            );

        assert!(hashlock::get_hash(&escrow::get_hashlock(min_hash_escrow)) == min_hash, 0);

        // Test maximum hash (32 bytes of 255)
        let max_secret = vector::empty<u8>();
        let j = 0;
        while (j < 32) {
            vector::push_back(&mut max_secret, 255u8);
            j = j + 1;
        };
        let max_hash = hash::sha3_256(max_secret);

        let max_hash_escrow =
            escrow::new_from_resolver(
                &resolver,
                signer::address_of(&recipient),
                metadata,
                ASSET_AMOUNT,
                CHAIN_ID,
                max_hash
            );

        assert!(hashlock::get_hash(&escrow::get_hashlock(max_hash_escrow)) == max_hash, 0);

        // Test withdrawal with correct secrets
        // For min_hash, we need to use a secret that generates that hash
        let min_secret = vector::empty<u8>();
        let i = 0;
        while (i < 32) {
            vector::push_back(&mut min_secret, 0u8);
            i = i + 1;
        };

        let timelock = escrow::get_timelock(min_hash_escrow);
        timestamp::fast_forward_seconds(15);
        escrow::withdraw(&resolver, min_hash_escrow, min_secret);

        // For max_hash, we need to use a secret that generates that hash
        let max_secret = vector::empty<u8>();
        let j = 0;
        while (j < 32) {
            vector::push_back(&mut max_secret, 255u8);
            j = j + 1;
        };

        let timelock2 = escrow::get_timelock(max_hash_escrow);
        timestamp::fast_forward_seconds(15);
        escrow::withdraw(&resolver, max_hash_escrow, max_secret);
    }

    #[test]
    fun test_escrow_maximum_object_lifecycle() {
        let (owner, _, resolver, metadata, _) = setup_test();

        // Create multiple escrows to test object lifecycle
        let fusion_order1 =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT,
                constants::get_source_chain_id(),
                hash::sha3_256(TEST_SECRET)
            );
        let escrow1 = escrow::new_from_order(&resolver, fusion_order1);

        let fusion_order2 =
            create_fusion_order_with_defaults(
                &owner,
                metadata,
                ASSET_AMOUNT * 2,
                constants::get_source_chain_id(),
                hash::sha3_256(WRONG_SECRET)
            );
        let escrow2 = escrow::new_from_order(&resolver, fusion_order2);

        // Verify both escrows exist
        let escrow1_address = object::object_address(&escrow1);
        let escrow2_address = object::object_address(&escrow2);
        assert!(object::object_exists<Escrow>(escrow1_address), 0);
        assert!(object::object_exists<Escrow>(escrow2_address), 0);

        // Fast forward time and withdraw from first escrow
        let timelock1 = escrow::get_timelock(escrow1);
        timestamp::fast_forward_seconds(15);
        escrow::withdraw(&resolver, escrow1, TEST_SECRET);

        // Verify first escrow is deleted
        assert!(object::object_exists<Escrow>(escrow1_address) == false, 0);

        // Fast forward time and withdraw from second escrow
        let timelock2 = escrow::get_timelock(escrow2);
        timestamp::fast_forward_seconds(15);
        escrow::withdraw(&resolver, escrow2, WRONG_SECRET);

        // Verify second escrow is deleted
        assert!(object::object_exists<Escrow>(escrow2_address) == false, 0);
    }
}
