module aptos_fusion_plus::timelock {
    use aptos_framework::timestamp;
    use aptos_fusion_plus::constants;

    /// Error codes
    const EINVALID_DURATION: u64 = 1;
    const EOVERFLOW: u64 = 2;
    const EINVALID_CHAIN_TYPE: u64 = 3;

    /// Chain type constants
    const CHAIN_TYPE_SOURCE: u8 = 0;
    const CHAIN_TYPE_DESTINATION: u8 = 1;

    /// Phase constants for Source Chain
    const SRC_PHASE_WITHDRAWAL: u8 = 0; // 0-10s: Only withdrawal with secret
    const SRC_PHASE_PUBLIC_WITHDRAWAL: u8 = 1; // 10-120s: Public withdrawal with secret
    const SRC_PHASE_CANCELLATION: u8 = 2; // 120-121s: Cancellation by owner
    const SRC_PHASE_PUBLIC_CANCELLATION: u8 = 3; // 121-122s: Public cancellation

    /// Phase constants for Destination Chain
    const DST_PHASE_WITHDRAWAL: u8 = 0; // 0-10s: Only withdrawal with secret
    const DST_PHASE_PUBLIC_WITHDRAWAL: u8 = 1; // 10-100s: Public withdrawal with secret
    const DST_PHASE_CANCELLATION: u8 = 2; // 100-101s: Cancellation by owner

    /// A timelock that enforces time-based phases for asset locking.
    /// Matches the 1inch Fusion+ EVM timelock structure with separate
    /// source and destination chain timelocks.
    ///
    /// @param created_at When this timelock was created.
    /// @param chain_type Whether this is source (0) or destination (1) chain.
    struct Timelock has copy, drop, store {
        created_at: u64,
        chain_type: u8
    }

    public fun new(): Timelock {
        new_internal(CHAIN_TYPE_SOURCE) // Default to source chain
    }

    /// Creates a new Timelock for the specified chain type.
    ///
    /// @param chain_type CHAIN_TYPE_SOURCE (0) or CHAIN_TYPE_DESTINATION (1)
    ///
    /// @reverts EINVALID_CHAIN_TYPE if chain_type is invalid.
    public fun new_internal(chain_type: u8): Timelock {
        assert!(chain_type == CHAIN_TYPE_SOURCE || chain_type == CHAIN_TYPE_DESTINATION, EINVALID_CHAIN_TYPE);

        Timelock {
            created_at: timestamp::now_seconds(),
            chain_type
        }
    }

    /// Creates a new Timelock for source chain.
    public fun new_source(): Timelock {
        new_internal(CHAIN_TYPE_SOURCE)
    }

    /// Creates a new Timelock for destination chain.
    public fun new_destination(): Timelock {
        new_internal(CHAIN_TYPE_DESTINATION)
    }

    /// Gets the current phase of a Timelock based on elapsed time.
    ///
    /// @param timelock The Timelock to check.
    /// @return u8 The current phase based on chain type and elapsed time.
    public fun get_phase(timelock: &Timelock): u8 {
        let now = timestamp::now_seconds();
        let elapsed = now - timelock.created_at;

        if (timelock.chain_type == CHAIN_TYPE_SOURCE) {
            get_source_phase(elapsed)
        } else {
            get_destination_phase(elapsed)
        }
    }

    /// Gets the source chain phase based on elapsed time.
    fun get_source_phase(elapsed: u64): u8 {
        if (elapsed < constants::get_src_withdrawal()) {
            SRC_PHASE_WITHDRAWAL
        } else if (elapsed < constants::get_src_public_withdrawal()) {
            SRC_PHASE_PUBLIC_WITHDRAWAL
        } else if (elapsed < constants::get_src_cancellation()) {
            SRC_PHASE_CANCELLATION
        } else if (elapsed < constants::get_src_public_cancellation()) {
            SRC_PHASE_PUBLIC_CANCELLATION
        } else {
            SRC_PHASE_PUBLIC_CANCELLATION // Final phase
        }
    }

    /// Gets the destination chain phase based on elapsed time.
    fun get_destination_phase(elapsed: u64): u8 {
        if (elapsed < constants::get_dst_withdrawal()) {
            DST_PHASE_WITHDRAWAL
        } else if (elapsed < constants::get_dst_public_withdrawal()) {
            DST_PHASE_PUBLIC_WITHDRAWAL
        } else if (elapsed < constants::get_dst_cancellation()) {
            DST_PHASE_CANCELLATION
        } else {
            DST_PHASE_CANCELLATION // Final phase
        }
    }

    /// Gets the remaining time in the current phase.
    ///
    /// @param timelock The Timelock to check.
    /// @return u64 The remaining time in seconds, or 0 if in final phase.
    public fun get_remaining_time(timelock: &Timelock): u64 {
        let now = timestamp::now_seconds();
        let elapsed = now - timelock.created_at;

        if (timelock.chain_type == CHAIN_TYPE_SOURCE) {
            get_source_remaining_time(elapsed)
        } else {
            get_destination_remaining_time(elapsed)
        }
    }

    /// Gets the remaining time for source chain phases.
    fun get_source_remaining_time(elapsed: u64): u64 {
        if (elapsed < constants::get_src_withdrawal()) {
            constants::get_src_withdrawal() - elapsed
        } else if (elapsed < constants::get_src_public_withdrawal()) {
            constants::get_src_public_withdrawal() - elapsed
        } else if (elapsed < constants::get_src_cancellation()) {
            constants::get_src_cancellation() - elapsed
        } else if (elapsed < constants::get_src_public_cancellation()) {
            constants::get_src_public_cancellation() - elapsed
        } else {
            0
        }
    }

    /// Gets the remaining time for destination chain phases.
    fun get_destination_remaining_time(elapsed: u64): u64 {
        if (elapsed < constants::get_dst_withdrawal()) {
            constants::get_dst_withdrawal() - elapsed
        } else if (elapsed < constants::get_dst_public_withdrawal()) {
            constants::get_dst_public_withdrawal() - elapsed
        } else if (elapsed < constants::get_dst_cancellation()) {
            constants::get_dst_cancellation() - elapsed
        } else {
            0
        }
    }

    /// Gets the total duration of all phases for the chain type.
    ///
    /// @param timelock The Timelock to check.
    /// @return u64 The total duration in seconds.
    public fun get_total_duration(timelock: &Timelock): u64 {
        if (timelock.chain_type == CHAIN_TYPE_SOURCE) {
            constants::get_src_public_cancellation()
        } else {
            constants::get_dst_cancellation()
        }
    }

    /// Gets the end time of the timelock (when it expires).
    ///
    /// @param timelock The Timelock to check.
    /// @return u64 The expiration timestamp in seconds.
    public fun get_expiration_time(timelock: &Timelock): u64 {
        timelock.created_at + get_total_duration(timelock)
    }

    /// Checks if the timelock is in the withdrawal phase (with secret only).
    ///
    /// @param timelock The Timelock to check.
    /// @return bool True if in withdrawal phase, false otherwise.
    public fun is_in_withdrawal_phase(timelock: &Timelock): bool {
        get_phase(timelock) == SRC_PHASE_WITHDRAWAL || get_phase(timelock) == DST_PHASE_WITHDRAWAL
    }

    /// Checks if the timelock is in the public withdrawal phase.
    ///
    /// @param timelock The Timelock to check.
    /// @return bool True if in public withdrawal phase, false otherwise.
    public fun is_in_public_withdrawal_phase(timelock: &Timelock): bool {
        get_phase(timelock) == SRC_PHASE_PUBLIC_WITHDRAWAL || get_phase(timelock) == DST_PHASE_PUBLIC_WITHDRAWAL
    }

    /// Checks if the timelock is in the cancellation phase.
    ///
    /// @param timelock The Timelock to check.
    /// @return bool True if in cancellation phase, false otherwise.
    public fun is_in_cancellation_phase(timelock: &Timelock): bool {
        get_phase(timelock) == SRC_PHASE_CANCELLATION || get_phase(timelock) == DST_PHASE_CANCELLATION
    }

    /// Checks if the timelock is in the public cancellation phase (source chain only).
    ///
    /// @param timelock The Timelock to check.
    /// @return bool True if in public cancellation phase, false otherwise.
    public fun is_in_public_cancellation_phase(timelock: &Timelock): bool {
        get_phase(timelock) == SRC_PHASE_PUBLIC_CANCELLATION
    }

    /// Gets the creation timestamp of the timelock.
    ///
    /// @param timelock The Timelock to get timestamp from.
    /// @return u64 The creation timestamp in seconds.
    public fun get_created_at(timelock: &Timelock): u64 {
        timelock.created_at
    }

    /// Gets the chain type of the timelock.
    ///
    /// @param timelock The Timelock to get chain type from.
    /// @return u8 The chain type (CHAIN_TYPE_SOURCE or CHAIN_TYPE_DESTINATION).
    public fun get_chain_type(timelock: &Timelock): u8 {
        timelock.chain_type
    }

    /// Checks if this is a source chain timelock.
    ///
    /// @param timelock The Timelock to check.
    /// @return bool True if source chain, false otherwise.
    public fun is_source_chain(timelock: &Timelock): bool {
        timelock.chain_type == CHAIN_TYPE_SOURCE
    }

    /// Checks if this is a destination chain timelock.
    ///
    /// @param timelock The Timelock to check.
    /// @return bool True if destination chain, false otherwise.
    public fun is_destination_chain(timelock: &Timelock): bool {
        timelock.chain_type == CHAIN_TYPE_DESTINATION
    }

    // Test functions
    #[test_only]
    public fun get_chain_type_source(): u8 {
        CHAIN_TYPE_SOURCE
    }

    #[test_only]
    public fun get_chain_type_destination(): u8 {
        CHAIN_TYPE_DESTINATION
    }

    #[test_only]
    public fun get_src_phase_withdrawal(): u8 {
        SRC_PHASE_WITHDRAWAL
    }

    #[test_only]
    public fun get_src_phase_public_withdrawal(): u8 {
        SRC_PHASE_PUBLIC_WITHDRAWAL
    }

    #[test_only]
    public fun get_src_phase_cancellation(): u8 {
        SRC_PHASE_CANCELLATION
    }

    #[test_only]
    public fun get_src_phase_public_cancellation(): u8 {
        SRC_PHASE_PUBLIC_CANCELLATION
    }

    #[test_only]
    public fun get_dst_phase_withdrawal(): u8 {
        DST_PHASE_WITHDRAWAL
    }

    #[test_only]
    public fun get_dst_phase_public_withdrawal(): u8 {
        DST_PHASE_PUBLIC_WITHDRAWAL
    }

    #[test_only]
    public fun get_dst_phase_cancellation(): u8 {
        DST_PHASE_CANCELLATION
    }

    #[test_only]
    public fun new_for_test(chain_type: u8): Timelock {
        new_internal(chain_type)
    }
}
