#[test_only]
module aptos_fusion_plus::resolver_registry_tests {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_fusion_plus::resolver_registry::{Self};

    fun setup_test(): (signer, signer, signer) {
        timestamp::set_time_has_started_for_testing(
            &account::create_signer_for_test(@aptos_framework)
        );
        let admin = account::create_account_for_test(@aptos_fusion_plus);

        timestamp::update_global_time_for_test_secs(1999);
        resolver_registry::init_module_for_test();

        let resolver1 = account::create_account_for_test(@0x201);
        let resolver2 = account::create_account_for_test(@0x202);

        (admin, resolver1, resolver2)
    }

    #[test]
    fun test_register_resolver_happy_flow() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Verify resolver is active
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Verify registration timestamp
        let registered_at =
            resolver_registry::get_resolver_registered_at(resolver_address);
        assert!(registered_at > 0, 0);

        // Verify last status change timestamp
        let last_status_change =
            resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(last_status_change > 0, 0);
        assert!(last_status_change == registered_at, 0); // Should be same initially
    }

    #[test]
    fun test_register_multiple_resolvers() {
        let (admin, resolver1, resolver2) = setup_test();

        let resolver1_address = signer::address_of(&resolver1);
        let resolver2_address = signer::address_of(&resolver2);

        // Register first resolver
        resolver_registry::register_resolver(&admin, resolver1_address);
        assert!(resolver_registry::is_active_resolver(resolver1_address), 0);

        // Register second resolver
        resolver_registry::register_resolver(&admin, resolver2_address);
        assert!(resolver_registry::is_active_resolver(resolver2_address), 0);

        // Verify both are active
        assert!(resolver_registry::is_active_resolver(resolver1_address), 0);
        assert!(resolver_registry::is_active_resolver(resolver2_address), 0);
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::EALREADY_REGISTERED)]
    fun test_register_resolver_already_registered() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver first time
        resolver_registry::register_resolver(&admin, resolver_address);

        // Try to register same resolver again
        resolver_registry::register_resolver(&admin, resolver_address);
    }

    #[test]
    fun test_deactivate_resolver_happy_flow() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Fast forward time before deactivation
        timestamp::fast_forward_seconds(100);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);

        // Verify resolver is inactive
        assert!(resolver_registry::is_active_resolver(resolver_address) == false, 0);

        // Verify last status change timestamp updated
        let last_status_change =
            resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(
            last_status_change
                > resolver_registry::get_resolver_registered_at(resolver_address),
            0
        );
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::ENOT_AUTHORIZED)]
    fun test_deactivate_resolver_unauthorized() {
        let (admin, resolver, unauthorized) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Try to deactivate with unauthorized account
        resolver_registry::deactivate_resolver(&unauthorized, resolver_address);
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::ENOT_REGISTERED)]
    fun test_deactivate_resolver_not_registered() {
        let (admin, _, _) = setup_test();

        let unregistered_address = @0x999;

        // Try to deactivate unregistered resolver
        resolver_registry::deactivate_resolver(&admin, unregistered_address);
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::EINVALID_STATUS_CHANGE)]
    fun test_deactivate_resolver_already_inactive() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);

        // Try to deactivate again
        resolver_registry::deactivate_resolver(&admin, resolver_address);
    }

    #[test]
    fun test_reactivate_resolver_happy_flow() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Fast forward time before deactivation
        timestamp::fast_forward_seconds(100);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address) == false, 0);

        // Fast forward time before reactivation
        timestamp::fast_forward_seconds(100);

        // Reactivate resolver
        resolver_registry::reactivate_resolver(&admin, resolver_address);

        // Verify resolver is active again
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Verify last status change timestamp updated
        let last_status_change =
            resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(
            last_status_change
                > resolver_registry::get_resolver_registered_at(resolver_address),
            0
        );
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::ENOT_AUTHORIZED)]
    fun test_reactivate_resolver_unauthorized() {
        let (admin, resolver, unauthorized) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);

        // Try to reactivate with unauthorized account
        resolver_registry::reactivate_resolver(&unauthorized, resolver_address);
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::ENOT_REGISTERED)]
    fun test_reactivate_resolver_not_registered() {
        let (admin, _, _) = setup_test();

        let unregistered_address = @0x999;

        // Try to reactivate unregistered resolver
        resolver_registry::reactivate_resolver(&admin, unregistered_address);
    }

    #[test]
    #[expected_failure(abort_code = resolver_registry::EINVALID_STATUS_CHANGE)]
    fun test_reactivate_resolver_already_active() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver (already active)
        resolver_registry::register_resolver(&admin, resolver_address);

        // Try to reactivate already active resolver
        resolver_registry::reactivate_resolver(&admin, resolver_address);
    }

    #[test]
    fun test_is_active_resolver_edge_cases() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);
        let unregistered_address = @0x999;

        // Test unregistered address
        assert!(resolver_registry::is_active_resolver(unregistered_address) == false, 0);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address) == false, 0);

        // Reactivate resolver
        resolver_registry::reactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);
    }

    #[test]
    fun test_resolver_lifecycle_complete() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);
        assert!(!resolver_registry::is_active_resolver(resolver_address), 0);

        // Reactivate resolver
        resolver_registry::reactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);
    }

    #[test]
    fun test_multiple_resolvers_independent_lifecycle() {
        let (admin, resolver1, resolver2) = setup_test();

        let resolver1_address = signer::address_of(&resolver1);
        let resolver2_address = signer::address_of(&resolver2);

        // Register both resolvers
        resolver_registry::register_resolver(&admin, resolver1_address);
        resolver_registry::register_resolver(&admin, resolver2_address);

        assert!(resolver_registry::is_active_resolver(resolver1_address), 0);
        assert!(resolver_registry::is_active_resolver(resolver2_address), 0);

        // Deactivate only resolver1
        resolver_registry::deactivate_resolver(&admin, resolver1_address);

        assert!(resolver_registry::is_active_resolver(resolver1_address) == false, 0);
        assert!(resolver_registry::is_active_resolver(resolver2_address), 0); // Still active

        // Reactivate resolver1
        resolver_registry::reactivate_resolver(&admin, resolver1_address);

        assert!(resolver_registry::is_active_resolver(resolver1_address), 0);
        assert!(resolver_registry::is_active_resolver(resolver2_address), 0); // Still active

        // Deactivate resolver2
        resolver_registry::deactivate_resolver(&admin, resolver2_address);

        assert!(resolver_registry::is_active_resolver(resolver1_address), 0); // Still active
        assert!(resolver_registry::is_active_resolver(resolver2_address) == false, 0);
    }

    // - - - - FIXED REMOVED TESTS - - - -

    #[test]
    fun test_resolver_boundary_addresses() {
        let (admin, _, _) = setup_test();

        // Test minimum address (0x0)
        let min_address = @0x0;
        resolver_registry::register_resolver(&admin, min_address);
        assert!(resolver_registry::is_active_resolver(min_address), 0);
        resolver_registry::deactivate_resolver(&admin, min_address);
        assert!(resolver_registry::is_active_resolver(min_address) == false, 0);

        // Test maximum address (0xffff...)
        let max_address = @0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        resolver_registry::register_resolver(&admin, max_address);
        assert!(resolver_registry::is_active_resolver(max_address), 0);
        resolver_registry::deactivate_resolver(&admin, max_address);
        assert!(resolver_registry::is_active_resolver(max_address) == false, 0);
    }

    #[test]
    fun test_resolver_concurrent_registration() {
        let (admin, resolver1, resolver2) = setup_test();

        let resolver1_address = signer::address_of(&resolver1);
        let resolver2_address = signer::address_of(&resolver2);

        // Register both resolvers concurrently (simulated)
        resolver_registry::register_resolver(&admin, resolver1_address);
        resolver_registry::register_resolver(&admin, resolver2_address);

        // Verify both are registered
        assert!(resolver_registry::is_active_resolver(resolver1_address), 0);
        assert!(resolver_registry::is_active_resolver(resolver2_address), 0);

        // Verify registration timestamps are close
        let registered_at1 = resolver_registry::get_resolver_registered_at(resolver1_address);
        let registered_at2 = resolver_registry::get_resolver_registered_at(resolver2_address);
        assert!(registered_at1 > 0, 0);
        assert!(registered_at2 > 0, 0);
    }

    #[test]
    fun test_resolver_multiple_rapid_operations() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        // Perform rapid status changes
        resolver_registry::deactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address) == false, 0);

        resolver_registry::reactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);

        resolver_registry::deactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address) == false, 0);

        resolver_registry::reactivate_resolver(&admin, resolver_address);
        assert!(resolver_registry::is_active_resolver(resolver_address), 0);
    }

    #[test]
    fun test_resolver_rapid_status_changes() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Perform rapid status changes with minimal time between
        let initial_status_change = resolver_registry::get_resolver_last_status_change(resolver_address);

        // Fast forward time before deactivation
        timestamp::fast_forward_seconds(1);

        // Deactivate
        resolver_registry::deactivate_resolver(&admin, resolver_address);
        let status_change1 = resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(status_change1 > initial_status_change, 0);

        // Fast forward time before reactivation
        timestamp::fast_forward_seconds(1);

        // Reactivate immediately
        resolver_registry::reactivate_resolver(&admin, resolver_address);
        let status_change2 = resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(status_change2 > status_change1, 0);

        // Fast forward time before second deactivation
        timestamp::fast_forward_seconds(1);

        // Deactivate again
        resolver_registry::deactivate_resolver(&admin, resolver_address);
        let status_change3 = resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(status_change3 > status_change2, 0);
    }

    #[test]
    fun test_resolver_timestamp_edge_cases() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Test timestamp consistency
        let registered_at = resolver_registry::get_resolver_registered_at(resolver_address);
        let initial_status_change = resolver_registry::get_resolver_last_status_change(resolver_address);

        assert!(registered_at > 0, 0);
        assert!(initial_status_change > 0, 0);
        assert!(initial_status_change == registered_at, 0); // Should be same initially

        // Fast forward time
        timestamp::fast_forward_seconds(100);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);

        let final_status_change = resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(final_status_change > initial_status_change, 0);
        assert!(final_status_change > registered_at, 0);
    }

    #[test]
    fun test_resolver_timestamps() {
        let (admin, resolver, _) = setup_test();

        let resolver_address = signer::address_of(&resolver);

        // Record time before registration
        let before_registration = timestamp::now_seconds();

        // Register resolver
        resolver_registry::register_resolver(&admin, resolver_address);

        // Verify registration timestamp
        let registered_at = resolver_registry::get_resolver_registered_at(resolver_address);
        assert!(registered_at >= before_registration, 0);

        // Verify initial status change timestamp
        let initial_status_change = resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(initial_status_change == registered_at, 0);

        // Fast forward time
        timestamp::fast_forward_seconds(50);

        // Deactivate resolver
        resolver_registry::deactivate_resolver(&admin, resolver_address);

        // Verify status change timestamp updated
        let final_status_change = resolver_registry::get_resolver_last_status_change(resolver_address);
        assert!(final_status_change > initial_status_change, 0);
        assert!(final_status_change > registered_at, 0);
    }
}
