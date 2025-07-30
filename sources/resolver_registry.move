module aptos_fusion_plus::resolver_registry {

    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;
    use aptos_framework::event;

    // - - - - ERROR CODES - - - -

    /// Unauthorized access attempt
    const ENOT_AUTHORIZED: u64 = 0;
    /// Invalid status change (e.g., deactivating already inactive resolver)
    const EINVALID_STATUS_CHANGE: u64 = 1;
    /// Resolver not found in registry
    const ENOT_REGISTERED: u64 = 2;
    /// Resolver already registered
    const EALREADY_REGISTERED: u64 = 3;

    // - - - - EVENTS - - - -

    #[event]
    /// Event emitted when a new resolver is registered
    /// 
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - This event indicates a new resolver has been whitelisted
    /// - Only registered resolvers can participate in cross-chain swaps
    /// - Resolvers must be registered before they can accept fusion orders
    /// 
    /// RESOLVER SHOULD:
    /// 1. Monitor this event to know when new resolvers are added
    /// 2. Track registered resolver addresses for potential collaboration
    /// 3. Ensure you are registered before attempting cross-chain swaps
    /// 4. Use this for resolver network monitoring
    struct ResolverRegisteredEvent has drop, store {
        resolver: address,    // Address of the newly registered resolver
        registered_at: u64    // Timestamp when registration occurred
    }

    #[event]
    /// Event emitted when a resolver's status changes
    /// 
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - This event indicates a resolver has been activated or deactivated
    /// - is_active = true: Resolver can participate in cross-chain swaps
    /// - is_active = false: Resolver is temporarily disabled
    /// 
    /// RESOLVER SHOULD:
    /// 1. Monitor this event to track resolver status changes
    /// 2. Check if you are still active before accepting new orders
    /// 3. Handle deactivation gracefully (complete existing swaps)
    /// 4. Use this for resolver network health monitoring
    struct ResolverStatusEvent has drop, store {
        resolver: address,    // Address of the resolver whose status changed
        is_active: bool,      // TRUE = active, FALSE = inactive
        changed_at: u64       // Timestamp when status changed
    }

    // - - - - STRUCTS - - - -

    /// Resolver information stored in the registry.
    ///
    /// @param registered_at Timestamp when the resolver was registered.
    /// @param last_status_change Timestamp of the last status change (activation/deactivation).
    /// @param status Current status of the resolver (true = active, false = inactive).
    struct Resolver has store {
        registered_at: u64,
        last_status_change: u64,
        status: bool
    }

    /// Global resolver registry that stores all registered resolvers.
    ///
    /// @param resolvers Table mapping resolver addresses to their information.
    struct ResolverRegistry has key {
        resolvers: Table<address, Resolver>
    }

    // - - - - INITIALIZATION - - - -

    /// Initializes the resolver registry module.
    /// This function is called during module deployment.
    ///
    /// @param signer The signer of the fusion_plus account.
    fun init_module(signer: &signer) {
        let resolver_registry =
            ResolverRegistry {
                resolvers: table::new<address, Resolver>()
            };
        move_to(signer, resolver_registry);
    }

    // - - - - PUBLIC FUNCTIONS - - - -

    /// Registers a new resolver in the registry.
    /// Only the admin (@aptos_fusion_plus) can register resolvers.
    ///
    /// @param signer The signer of the admin account.
    /// @param address The address of the resolver to register.
    ///
    /// @reverts ENOT_AUTHORIZED if the signer is not the admin.
    /// @reverts EALREADY_REGISTERED if the resolver is already registered.
    public entry fun register_resolver(signer: &signer, address: address) acquires ResolverRegistry {
        assert_is_admin(signer);
        assert!(!resolver_exists(address), EALREADY_REGISTERED);

        let resolver_registry = borrow_resolver_registry_mut(@aptos_fusion_plus);
        let now = timestamp::now_seconds();

        let resolver = Resolver {
            registered_at: now,
            last_status_change: now,
            status: true
        };

        resolver_registry.resolvers.add(address, resolver);

        // Emit registration event
        event::emit(
            ResolverRegisteredEvent { resolver: address, registered_at: now }
        );

        // Emit initial status event
        event::emit(
            ResolverStatusEvent { resolver: address, is_active: true, changed_at: now }
        );
    }

    /// Deactivates a registered resolver.
    /// Only the admin (@aptos_fusion_plus) can deactivate resolvers.
    ///
    /// @param signer The signer of the admin account.
    /// @param address The address of the resolver to deactivate.
    ///
    /// @reverts ENOT_AUTHORIZED if the signer is not the admin.
    /// @reverts ENOT_REGISTERED if the resolver is not registered.
    /// @reverts EINVALID_STATUS_CHANGE if the resolver is already inactive.
    public entry fun deactivate_resolver(signer: &signer, address: address) acquires ResolverRegistry {
        assert_is_admin(signer);
        assert!(resolver_exists(address), ENOT_REGISTERED);

        let resolver_registry = borrow_resolver_registry_mut(@aptos_fusion_plus);
        let resolver = resolver_registry.resolvers.borrow_mut(address);

        assert!(resolver.status == true, EINVALID_STATUS_CHANGE);

        let now = timestamp::now_seconds();
        resolver.status = false;
        resolver.last_status_change = now;

        // Emit status change event
        event::emit(
            ResolverStatusEvent { resolver: address, is_active: false, changed_at: now }
        );
    }

    /// Reactivates a deactivated resolver.
    /// Only the admin (@aptos_fusion_plus) can reactivate resolvers.
    ///
    /// @param signer The signer of the admin account.
    /// @param address The address of the resolver to reactivate.
    ///
    /// @reverts ENOT_AUTHORIZED if the signer is not the admin.
    /// @reverts ENOT_REGISTERED if the resolver is not registered.
    /// @reverts EINVALID_STATUS_CHANGE if the resolver is already active.
    public entry fun reactivate_resolver(signer: &signer, address: address) acquires ResolverRegistry {
        assert_is_admin(signer);
        assert!(resolver_exists(address), ENOT_REGISTERED);

        let resolver_registry = borrow_resolver_registry_mut(@aptos_fusion_plus);
        let resolver = resolver_registry.resolvers.borrow_mut(address);

        assert!(resolver.status == false, EINVALID_STATUS_CHANGE);

        let now = timestamp::now_seconds();
        resolver.status = true;
        resolver.last_status_change = now;

        // Emit status change event
        event::emit(
            ResolverStatusEvent { resolver: address, is_active: true, changed_at: now }
        );
    }

    // - - - - VIEW FUNCTIONS - - - -

    #[view]
    /// Gets the registration timestamp of a resolver.
    ///
    /// @param resolver The address of the resolver.
    /// @return u64 The registration timestamp.
    public fun get_resolver_registered_at(resolver: address): u64 acquires ResolverRegistry {
        let resolver_registry = borrow_resolver_registry(@aptos_fusion_plus);
        let resolver_data = resolver_registry.resolvers.borrow(resolver);
        resolver_data.registered_at
    }

    #[view]
    /// Gets the last status change timestamp of a resolver.
    ///
    /// @param resolver The address of the resolver.
    /// @return u64 The last status change timestamp.
    public fun get_resolver_last_status_change(resolver: address): u64 acquires ResolverRegistry {
        let resolver_registry = borrow_resolver_registry(@aptos_fusion_plus);
        let resolver_data = resolver_registry.resolvers.borrow(resolver);
        resolver_data.last_status_change
    }

    #[view]
    /// Checks if a resolver is currently active.
    ///
    /// @param address The address of the resolver to check.
    /// @return bool True if the resolver is registered and active, false otherwise.
    public fun is_active_resolver(address: address): bool acquires ResolverRegistry {
        let resolver_registry = borrow_resolver_registry(@aptos_fusion_plus);
        if (resolver_registry.resolvers.contains(address)) {
            let resolver = resolver_registry.resolvers.borrow(address);
            resolver.status
        } else { false }
    }

    // - - - - INTERNAL FUNCTIONS - - - -

    /// Checks if a resolver exists in the registry.
    ///
    /// @param address The address of the resolver to check.
    /// @return bool True if the resolver is registered, false otherwise.
    fun resolver_exists(address: address): bool acquires ResolverRegistry {
        let resolver_registry = borrow_resolver_registry(@aptos_fusion_plus);
        resolver_registry.resolvers.contains(address)
    }

    /// Asserts that the signer is the admin (@aptos_fusion_plus).
    ///
    /// @param account The signer to check.
    /// @reverts ENOT_AUTHORIZED if the signer is not the admin.
    fun assert_is_admin(account: &signer) {
        assert!(signer::address_of(account) == @aptos_fusion_plus, ENOT_AUTHORIZED);
    }

    // - - - - BORROW FUNCTIONS - - - -

    /// Borrows an immutable reference to the ResolverRegistry.
    ///
    /// @param address The address of the resolver registry.
    /// @return &ResolverRegistry Immutable reference to the resolver registry.
    inline fun borrow_resolver_registry(
        address: address
    ): &ResolverRegistry {
        borrow_global<ResolverRegistry>(address)
    }

    /// Borrows a mutable reference to the ResolverRegistry.
    ///
    /// @param address The address of the resolver registry.
    /// @return &mut ResolverRegistry Mutable reference to the resolver registry.
    inline fun borrow_resolver_registry_mut(
        address: address
    ): &mut ResolverRegistry {
        borrow_global_mut<ResolverRegistry>(address)
    }

    // - - - - TEST FUNCTIONS - - - -

    #[test_only]
    use aptos_framework::account;

    #[test_only]
    /// Initializes the module for testing purposes.
    public fun init_module_for_test() {
        init_module(&account::create_account_for_test(@aptos_fusion_plus));
    }
}
