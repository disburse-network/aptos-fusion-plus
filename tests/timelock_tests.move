#[test_only]
module aptos_fusion_plus::timelock_tests {
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_fusion_plus::timelock;

    // Test constants (updated for 1inch Fusion+ model)
    const FINALITY_LOCK_DURATION: u64 = 12;  // 12sec finality lock
    const WITHDRAWAL_DURATION: u64 = 24;     // 12sec exclusive withdrawal (24-12=12sec)
    const PUBLIC_WITHDRAWAL_DURATION: u64 = 120; // 96sec public withdrawal (120-24=96sec)
    const CANCELLATION_DURATION: u64 = 180;  // 60sec resolver cancellation (180-120=60sec)
    const PUBLIC_CANCELLATION_DURATION: u64 = 240; // 60sec public cancellation (240-180=60sec)

    #[test]
    fun test_create_timelock() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();

        // Verify timelock properties
        assert!(timelock::is_source_chain(&timelock), 0);
        assert!(!timelock::is_destination_chain(&timelock), 0);

        // Verify initial phase is finality lock (0-12s)
        assert!(timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);
    }

    #[test]
    fun test_create_destination_timelock() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_destination();

        // Verify timelock properties
        assert!(!timelock::is_source_chain(&timelock), 0);
        assert!(timelock::is_destination_chain(&timelock), 0);

        // Verify initial phase is finality lock (0-12s)
        assert!(timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);
    }

    #[test]
    fun test_source_chain_phase_transitions() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();

        // Initial phase: finality lock (0-12s)
        assert!(timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to withdrawal phase (12-24s)
        timestamp::update_global_time_for_test_secs(15);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to public withdrawal phase (24-120s)
        timestamp::update_global_time_for_test_secs(30);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to cancellation phase (120-180s)
        timestamp::update_global_time_for_test_secs(130);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to public cancellation phase (180-240s)
        timestamp::update_global_time_for_test_secs(190);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);
        assert!(timelock::is_in_public_cancellation_phase(&timelock), 0);
    }

    #[test]
    fun test_destination_chain_phase_transitions() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_destination();

        // Initial phase: finality lock (0-12s)
        assert!(timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to withdrawal phase (12-24s)
        timestamp::update_global_time_for_test_secs(15);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to public withdrawal phase (24-100s)
        timestamp::update_global_time_for_test_secs(30);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);

        // Fast forward to cancellation phase (100-160s)
        timestamp::update_global_time_for_test_secs(110);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_cancellation_phase(&timelock), 0);
    }

    #[test]
    fun test_remaining_time() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();

        // Initial remaining time should be > 0
        let remaining = timelock::get_remaining_time(&timelock);
        assert!(remaining > 0, 0);

        // Fast forward and check remaining time decreases
        timestamp::update_global_time_for_test_secs(5);
        let remaining_after_5s = timelock::get_remaining_time(&timelock);
        assert!(remaining_after_5s < remaining, 0);
        assert!(remaining_after_5s > 0, 0);
    }

    #[test]
    fun test_total_duration() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let source_timelock = timelock::new_source();
        let dest_timelock = timelock::new_destination();

        // Source chain total duration should be 240s
        assert!(timelock::get_total_duration(&source_timelock) == 240, 0);

        // Destination chain total duration should be 160s
        assert!(timelock::get_total_duration(&dest_timelock) == 160, 0);
    }

    #[test]
    fun test_expiration_time() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();
        let created_at = timelock::get_created_at(&timelock);
        let expiration = timelock::get_expiration_time(&timelock);

        // Expiration should be created_at + total_duration
        assert!(expiration == created_at + 240, 0);
    }

    #[test]
    fun test_chain_type_functions() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let source_timelock = timelock::new_source();
        let dest_timelock = timelock::new_destination();

        // Test chain type getters
        assert!(timelock::get_chain_type(&source_timelock) == timelock::get_chain_type_source(), 0);
        assert!(timelock::get_chain_type(&dest_timelock) == timelock::get_chain_type_destination(), 0);

        // Test chain type checks
        assert!(timelock::is_source_chain(&source_timelock), 0);
        assert!(!timelock::is_source_chain(&dest_timelock), 0);
        assert!(!timelock::is_destination_chain(&source_timelock), 0);
        assert!(timelock::is_destination_chain(&dest_timelock), 0);
    }

    #[test]
    #[expected_failure(abort_code = timelock::EINVALID_CHAIN_TYPE)]
    fun test_invalid_chain_type() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        // Try to create timelock with invalid chain type
        timelock::new_for_test(99); // Invalid chain type
    }

    #[test]
    fun test_exact_boundary_transitions() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();
        let created_at = timelock::get_created_at(&timelock);

        // Test exact boundary at 12 seconds (finality lock to withdrawal)
        timestamp::update_global_time_for_test_secs(created_at + 12);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(timelock::is_in_withdrawal_phase(&timelock), 0);

        // Test exact boundary at 24 seconds (withdrawal to public withdrawal)
        timestamp::update_global_time_for_test_secs(created_at + 24);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_public_withdrawal_phase(&timelock), 0);

        // Test exact boundary at 120 seconds (public withdrawal to cancellation)
        timestamp::update_global_time_for_test_secs(created_at + 120);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_cancellation_phase(&timelock), 0);

        // Test exact boundary at 180 seconds (cancellation to public cancellation)
        timestamp::update_global_time_for_test_secs(created_at + 180);
        assert!(!timelock::is_in_cancellation_phase(&timelock), 0);
        assert!(timelock::is_in_public_cancellation_phase(&timelock), 0);
    }

    #[test]
    fun test_destination_exact_boundary_transitions() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_destination();
        let created_at = timelock::get_created_at(&timelock);

        // Test exact boundary at 12 seconds (finality lock to withdrawal)
        timestamp::update_global_time_for_test_secs(created_at + 12);
        assert!(!timelock::is_in_finality_lock_phase(&timelock), 0);
        assert!(timelock::is_in_withdrawal_phase(&timelock), 0);

        // Test exact boundary at 24 seconds (withdrawal to public withdrawal)
        timestamp::update_global_time_for_test_secs(created_at + 24);
        assert!(!timelock::is_in_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_public_withdrawal_phase(&timelock), 0);

        // Test exact boundary at 100 seconds (public withdrawal to cancellation)
        timestamp::update_global_time_for_test_secs(created_at + 100);
        assert!(!timelock::is_in_public_withdrawal_phase(&timelock), 0);
        assert!(timelock::is_in_cancellation_phase(&timelock), 0);
    }

    #[test]
    fun test_phase_getter_functions() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        // Test source chain phase constants
        assert!(timelock::get_src_phase_finality_lock() == 0, 0);
        assert!(timelock::get_src_phase_withdrawal() == 1, 0);
        assert!(timelock::get_src_phase_public_withdrawal() == 2, 0);
        assert!(timelock::get_src_phase_cancellation() == 3, 0);
        assert!(timelock::get_src_phase_public_cancellation() == 4, 0);

        // Test destination chain phase constants
        assert!(timelock::get_dst_phase_finality_lock() == 0, 0);
        assert!(timelock::get_dst_phase_withdrawal() == 1, 0);
        assert!(timelock::get_dst_phase_public_withdrawal() == 2, 0);
        assert!(timelock::get_dst_phase_cancellation() == 3, 0);
    }

    #[test]
    fun test_remaining_time_edge_cases() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();
        let created_at = timelock::get_created_at(&timelock);

        // Test remaining time at exact boundaries
        timestamp::update_global_time_for_test_secs(created_at + 11); // Just before phase change
        let remaining_before = timelock::get_remaining_time(&timelock);
        assert!(remaining_before > 0, 0);

        timestamp::update_global_time_for_test_secs(created_at + 12); // At phase change
        let remaining_at = timelock::get_remaining_time(&timelock);
        assert!(remaining_at > 0, 0);

        timestamp::update_global_time_for_test_secs(created_at + 13); // Just after phase change
        let remaining_after = timelock::get_remaining_time(&timelock);
        assert!(remaining_after > 0, 0);
    }

    #[test]
    fun test_created_at_consistency() {
        let framework_signer = account::create_signer_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&framework_signer);

        let timelock = timelock::new_source();
        let created_at = timelock::get_created_at(&timelock);

        // Created at should be consistent
        assert!(timelock::get_created_at(&timelock) == created_at, 0);
        // Note: created_at can be 0 if timestamp is not properly initialized
        // So we don't assert it's > 0
    }
}
