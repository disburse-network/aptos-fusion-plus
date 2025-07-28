module aptos_fusion_plus::fusion_order {
    use std::signer;
    use aptos_framework::event::{Self};
    use aptos_framework::fungible_asset::{FungibleAsset, Metadata};
    use aptos_framework::object::{Self, Object, ExtendRef, DeleteRef, ObjectGroup};
    use aptos_framework::primary_fungible_store;

    use aptos_fusion_plus::constants;
    use aptos_fusion_plus::resolver_registry;

    friend aptos_fusion_plus::escrow;

    // - - - - ERROR CODES - - - -

    /// Invalid amount
    const EINVALID_AMOUNT: u64 = 1;
    /// Insufficient balance
    const EINSUFFICIENT_BALANCE: u64 = 2;
    /// Invalid caller
    const EINVALID_CALLER: u64 = 3;
    /// Object does not exist
    const EOBJECT_DOES_NOT_EXIST: u64 = 4;
    /// Invalid resolver
    const EINVALID_RESOLVER: u64 = 5;
    /// Invalid hash
    const EINVALID_HASH: u64 = 6;

    // - - - - EVENTS - - - -

    #[event]
    /// Event emitted when a fusion order is created
    /// 
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - This event indicates a user wants to swap assets to a different chain
    /// - chain_id: Shows which blockchain the user wants to swap TO
    /// - amount: How much the user wants to swap
    /// - metadata: What type of asset they want to swap
    /// 
    /// RESOLVER SHOULD:
    /// 1. Monitor these events to find swap opportunities
    /// 2. Check if you have matching assets on the destination chain
    /// 3. Evaluate if the swap is profitable for you
    /// 4. Call resolver_accept_order() if you want to accept the order
    struct FusionOrderCreatedEvent has drop, store {
        fusion_order: Object<FusionOrder>, // Order object address for tracking
        owner: address,                     // User who created the order
        metadata: Object<Metadata>,         // Asset type they want to swap
        amount: u64,                        // Amount they want to swap
        chain_id: u64                      // Destination chain ID
    }

    #[event]
    /// Event emitted when a fusion order is cancelled by the owner
    /// 
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - User cancelled their order before resolver picked it up
    /// - No action needed from resolver
    /// - Assets returned to user automatically
    /// 
    /// RESOLVER SHOULD:
    /// 1. Remove this order from your tracking
    /// 2. No cross-chain coordination needed
    struct FusionOrderCancelledEvent has drop, store {
        fusion_order: Object<FusionOrder>, // Order object that was cancelled
        owner: address,                     // User who cancelled the order
        metadata: Object<Metadata>,         // Asset type
        amount: u64                         // Amount that was cancelled
    }

    #[event]
    /// Event emitted when a fusion order is accepted by a resolver
    /// 
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - Resolver has accepted the order and created source chain escrow
    /// - Resolver must now create matching destination chain escrow
    /// - This triggers the cross-chain atomic swap process
    /// 
    /// RESOLVER SHOULD:
    /// 1. Create matching escrow on destination chain with same parameters
    /// 2. Monitor both escrows for withdrawal events
    /// 3. Handle the complete cross-chain swap lifecycle
    /// 4. Ensure atomic swap completion or proper cancellation
    struct FusionOrderAcceptedEvent has drop, store {
        fusion_order: Object<FusionOrder>, // Order object that was accepted
        resolver: address,                  // Resolver who accepted the order
        owner: address,                     // Original user who created the order
        metadata: Object<Metadata>,         // Asset type (must match across chains)
        amount: u64,                        // Amount (must match across chains)
        chain_id: u64                      // Destination chain ID
    }

    // - - - - STRUCTS - - - -

    #[resource_group_member(group = ObjectGroup)]
    /// Controller for managing the lifecycle of a FusionOrder.
    ///
    /// @param extend_ref The extend_ref of the fusion order, used to generate signer for the fusion order.
    /// @param delete_ref The delete ref of the fusion order, used to delete the fusion order.
    struct FusionOrderController has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef
    }

    /// A fusion order that represents a user's intent to swap assets across chains.
    /// The order can be cancelled by the owner before a resolver picks it up.
    /// Once picked up by a resolver, the order is converted to an escrow.
    ///
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - Users only deposit main asset (no safety deposit)
    /// - Resolvers provide safety deposit when accepting orders
    /// - This matches the actual 1inch Fusion+ protocol design
    ///
    /// @param owner The address of the user who created this order.
    /// @param metadata The metadata of the asset being swapped.
    /// @param amount The amount of the asset being swapped.
    /// @param safety_deposit_metadata The metadata of the safety deposit asset (resolver provides).
    /// @param safety_deposit_amount The amount of safety deposit (always 0 for user orders).
    /// @param chain_id The destination chain ID for the swap.
    /// @param hash The hash of the secret for the cross-chain swap.
    struct FusionOrder has key, store {
        owner: address,
        metadata: Object<Metadata>,
        amount: u64,
        safety_deposit_metadata: Object<Metadata>,
        safety_deposit_amount: u64, // Always 0 - resolver provides safety deposit
        chain_id: u64,
        hash: vector<u8>
    }

    // - - - - ENTRY FUNCTIONS - - - -

    /// Entry function for creating a new FusionOrder.
    public entry fun new_entry(
        signer: &signer,
        metadata: Object<Metadata>,
        amount: u64,
        chain_id: u64,
        hash: vector<u8>
    ) {
        new(signer, metadata, amount, chain_id, hash);
    }

    // - - - - PUBLIC FUNCTIONS - - - -

    /// Creates a new FusionOrder with the specified parameters.
    ///
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - User creates order with only main asset (no safety deposit)
    /// - Resolver provides safety deposit when accepting order
    /// - This matches the actual 1inch Fusion+ protocol design
    /// 
    /// RESOLVER SHOULD:
    /// 1. Monitor FusionOrderCreatedEvent to find orders
    /// 2. Provide safety deposit when accepting orders
    /// 3. Create matching destination chain escrow
    /// 4. Handle complete cross-chain swap lifecycle
    ///
    /// @param signer The signer of the user creating the order.
    /// @param metadata The metadata of the asset being swapped.
    /// @param amount The amount of the asset being swapped.
    /// @param chain_id The destination chain ID for the swap.
    /// @param hash The hash of the secret for the cross-chain swap.
    ///
    /// @reverts EINVALID_AMOUNT if amount is zero.
    /// @reverts EINSUFFICIENT_BALANCE if user has insufficient balance for main asset.
    /// @return Object<FusionOrder> The created fusion order object.
    public fun new(
        signer: &signer,
        metadata: Object<Metadata>,
        amount: u64,
        chain_id: u64,
        hash: vector<u8>
    ): Object<FusionOrder> {

        let signer_address = signer::address_of(signer);

        // Validate inputs
        assert!(amount > 0, EINVALID_AMOUNT);
        assert!(is_valid_hash(&hash), EINVALID_HASH);
        assert!(
            primary_fungible_store::balance(signer_address, metadata) >= amount,
            EINSUFFICIENT_BALANCE
        );

        // Create an object and FusionOrder
        let constructor_ref = object::create_object_from_account(signer);
        let object_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let delete_ref = object::generate_delete_ref(&constructor_ref);

        // Create the controller
        move_to(
            &object_signer,
            FusionOrderController { extend_ref, delete_ref }
        );

        // Create the FusionOrder
        // NOTE: No safety deposit from user - only resolver provides safety deposit
        let fusion_order = FusionOrder {
            owner: signer_address,
            metadata,
            amount,
            safety_deposit_metadata: constants::get_safety_deposit_metadata(),
            safety_deposit_amount: 0, // User doesn't provide safety deposit
            chain_id,
            hash
        };

        move_to(&object_signer, fusion_order);

        let object_address = signer::address_of(&object_signer);

        // Store only the main asset in the fusion order primary store
        // User does NOT provide safety deposit - only resolver does
        primary_fungible_store::ensure_primary_store_exists(object_address, metadata);
        primary_fungible_store::transfer(signer, metadata, object_address, amount);

        let fusion_order_obj = object::object_from_constructor_ref(&constructor_ref);

        // Emit creation event
        event::emit(
            FusionOrderCreatedEvent {
                fusion_order: fusion_order_obj,
                owner: signer_address,
                metadata,
                amount,
                chain_id
            }
        );

        fusion_order_obj

    }

    /// Cancels a fusion order and returns assets to the owner. This function can only be called by the owner before it is picked up by a resolver.
    ///
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - User cancels order before resolver picks it up
    /// - Only main asset is returned (no safety deposit since user never provided one)
    /// - No cross-chain coordination needed
    ///
    /// @param signer The signer of the order owner.
    /// @param fusion_order The fusion order to cancel.
    ///
    /// @reverts EOBJECT_DOES_NOT_EXIST if the fusion order does not exist.
    /// @reverts EINVALID_CALLER if the signer is not the order owner.
    public entry fun cancel(
        signer: &signer, fusion_order: Object<FusionOrder>
    ) acquires FusionOrder, FusionOrderController {
        let signer_address = signer::address_of(signer);

        assert!(order_exists(fusion_order), EOBJECT_DOES_NOT_EXIST);
        assert!(is_owner(fusion_order, signer_address), EINVALID_CALLER);

        let object_address = object::object_address(&fusion_order);
        let fusion_order_ref = borrow_fusion_order_mut(&fusion_order);
        let controller = borrow_fusion_order_controller_mut(&fusion_order);

        // Store event data before deletion
        let owner = fusion_order_ref.owner;
        let metadata = fusion_order_ref.metadata;
        let amount = fusion_order_ref.amount;

        let FusionOrderController { extend_ref, delete_ref } = move_from(object_address);

        let object_signer = object::generate_signer_for_extending(&extend_ref);

        // Return main asset to owner
        // NOTE: No safety deposit to return since user never provided one
        primary_fungible_store::transfer(
            &object_signer,
            fusion_order_ref.metadata,
            signer_address,
            fusion_order_ref.amount
        );

        object::delete(delete_ref);

        // Emit cancellation event
        event::emit(
            FusionOrderCancelledEvent { fusion_order, owner, metadata, amount }
        );

    }

    /// Allows an active resolver to accept a fusion order.
    /// This function is called from the escrow module when creating an escrow from a fusion order.
    ///
    /// CROSS-CHAIN RESOLVER LOGIC:
    /// - This function extracts assets from fusion order and creates source chain escrow
    /// - Assets stay in escrow (not with resolver) for hashlock/timelock protection
    /// - Resolver must then create matching destination chain escrow
    /// - Emits FusionOrderAcceptedEvent for cross-chain coordination
    /// 
    /// RESOLVER FLOW:
    /// 1. Monitor FusionOrderCreatedEvent to find orders you want to accept
    /// 2. Call escrow::new_from_order_entry() which internally calls this function
    /// 3. This function creates source chain escrow with user's assets
    /// 4. Resolver must then create matching destination chain escrow
    /// 5. Monitor both escrows for withdrawal events
    /// 
    /// RESOLVER RESPONSIBILITIES:
    /// 1. Ensure you have matching assets on destination chain before accepting
    /// 2. Provide safety deposit when accepting order (this is your skin in the game)
    /// 3. Monitor FusionOrderAcceptedEvent to know when order is accepted
    /// 4. Create destination chain escrow with same parameters
    /// 5. Handle the complete cross-chain swap lifecycle
    ///
    /// @param signer The signer of the resolver accepting the order.
    /// @param fusion_order The fusion order to accept.
    ///
    /// @reverts EOBJECT_DOES_NOT_EXIST if the fusion order does not exist.
    /// @reverts EINVALID_RESOLVER if the signer is not an active resolver.
    /// @reverts EINSUFFICIENT_BALANCE if resolver has insufficient safety deposit.
    /// @return (FungibleAsset, FungibleAsset) The main asset and safety deposit asset for escrow creation.
    public(friend) fun resolver_accept_order(
        signer: &signer, fusion_order: Object<FusionOrder>
    ): (FungibleAsset, FungibleAsset) acquires FusionOrder, FusionOrderController {
        let signer_address = signer::address_of(signer);

        assert!(order_exists(fusion_order), EOBJECT_DOES_NOT_EXIST);
        assert!(
            resolver_registry::is_active_resolver(signer_address), EINVALID_RESOLVER
        );

        let object_address = object::object_address(&fusion_order);
        let fusion_order_ref = borrow_fusion_order_mut(&fusion_order);
        let controller = borrow_fusion_order_controller_mut(&fusion_order);

        // Store event data before deletion
        // CROSS-CHAIN LOGIC: These values are used in FusionOrderAcceptedEvent
        // and must match the destination chain escrow parameters
        let owner = fusion_order_ref.owner;
        let metadata = fusion_order_ref.metadata;
        let amount = fusion_order_ref.amount;
        let chain_id = fusion_order_ref.chain_id;

        let FusionOrderController { extend_ref, delete_ref } = move_from(object_address);

        let object_signer = object::generate_signer_for_extending(&extend_ref);

        // Extract main asset from fusion order (user's asset)
        // CROSS-CHAIN LOGIC: This asset will be used to create source chain escrow
        let asset =
            primary_fungible_store::withdraw(
                &object_signer,
                fusion_order_ref.metadata,
                fusion_order_ref.amount
            );

        // Resolver provides safety deposit (user never provided one)
        // CROSS-CHAIN LOGIC: This ensures resolver has skin in the game
        let safety_deposit_asset =
            primary_fungible_store::withdraw(
                signer,
                constants::get_safety_deposit_metadata(),
                constants::get_safety_deposit_amount()
            );

        object::delete(delete_ref);

        // Emit acceptance event for cross-chain coordination
        // RESOLVER SHOULD MONITOR THIS EVENT:
        // - Track that order has been accepted
        // - Use metadata, amount, chain_id to create destination escrow
        // - Ensure matching parameters across both chains
        event::emit(
            FusionOrderAcceptedEvent {
                fusion_order,
                resolver: signer_address,
                owner,
                metadata,
                amount,
                chain_id
            }
        );

        // Return assets for escrow creation (not for resolver to keep)
        // CROSS-CHAIN LOGIC: These assets will be locked in escrow
        (asset, safety_deposit_asset)

    }

    // - - - - GETTER FUNCTIONS - - - -

    /// Gets the owner address of a fusion order.
    ///
    /// @param fusion_order The fusion order to get the owner from.
    /// @return address The owner address.
    public fun get_owner(fusion_order: Object<FusionOrder>): address acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.owner
    }

    /// Gets the metadata of the main asset in a fusion order.
    ///
    /// @param fusion_order The fusion order to get the metadata from.
    /// @return Object<Metadata> The metadata of the main asset.
    public fun get_metadata(
        fusion_order: Object<FusionOrder>
    ): Object<Metadata> acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.metadata
    }

    /// Gets the amount of the main asset in a fusion order.
    ///
    /// @param fusion_order The fusion order to get the amount from.
    /// @return u64 The amount of the main asset.
    public fun get_amount(fusion_order: Object<FusionOrder>): u64 acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.amount
    }

    /// Gets the metadata of the safety deposit asset in a fusion order.
    /// NOTE: Users don't provide safety deposits - only resolvers do
    ///
    /// @param fusion_order The fusion order to get the safety deposit metadata from.
    /// @return Object<Metadata> The metadata of the safety deposit asset.
    public fun get_safety_deposit_metadata(
        fusion_order: Object<FusionOrder>
    ): Object<Metadata> acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.safety_deposit_metadata
    }

    /// Gets the amount of the safety deposit in a fusion order.
    /// NOTE: This will always be 0 since users don't provide safety deposits
    /// Resolvers provide safety deposits when accepting orders
    ///
    /// @param fusion_order The fusion order to get the safety deposit amount from.
    /// @return u64 The amount of the safety deposit (always 0 for user orders).
    public fun get_safety_deposit_amount(
        fusion_order: Object<FusionOrder>
    ): u64 acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.safety_deposit_amount // Always 0 since user doesn't provide safety deposit
    }

    /// Gets the destination chain ID of a fusion order.
    ///
    /// @param fusion_order The fusion order to get the chain ID from.
    /// @return u64 The destination chain ID.
    public fun get_chain_id(fusion_order: Object<FusionOrder>): u64 acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.chain_id
    }

    /// Gets the hash of the secret in a fusion order.
    ///
    /// @param fusion_order The fusion order to get the hash from.
    /// @return vector<u8> The hash of the secret.
    public fun get_hash(fusion_order: Object<FusionOrder>): vector<u8> acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.hash
    }

    /// Checks if a hash value is valid (non-empty).
    ///
    /// @param hash The hash value to check.
    /// @return bool True if the hash is valid, false otherwise.
    public fun is_valid_hash(hash: &vector<u8>): bool {
        std::vector::length(hash) > 0
    }

    /// Checks if a fusion order exists.
    ///
    /// @param fusion_order The fusion order object to check.
    /// @return bool True if the fusion order exists, false otherwise.
    public fun order_exists(fusion_order: Object<FusionOrder>): bool {
        object::object_exists<FusionOrder>(object::object_address(&fusion_order))
    }

    /// Checks if an address is the owner of a fusion order.
    ///
    /// @param fusion_order The fusion order to check.
    /// @param address The address to check against.
    /// @return bool True if the address is the owner, false otherwise.
    public fun is_owner(
        fusion_order: Object<FusionOrder>, address: address
    ): bool acquires FusionOrder {
        let fusion_order_ref = borrow_fusion_order(&fusion_order);
        fusion_order_ref.owner == address
    }

    // - - - - BORROW FUNCTIONS - - - -

    /// Borrows a mutable reference to the FusionOrderController.
    ///
    /// @param fusion_order_obj The fusion order object.
    /// @return &FusionOrderController Mutable reference to the controller.
    inline fun borrow_fusion_order_controller_mut(
        fusion_order_obj: &Object<FusionOrder>
    ): &FusionOrderController acquires FusionOrderController {
        borrow_global_mut<FusionOrderController>(object::object_address(fusion_order_obj))
    }

    /// Borrows an immutable reference to the FusionOrder.
    ///
    /// @param fusion_order_obj The fusion order object.
    /// @return &FusionOrder Immutable reference to the fusion order.
    inline fun borrow_fusion_order(
        fusion_order_obj: &Object<FusionOrder>
    ): &FusionOrder acquires FusionOrder {
        borrow_global<FusionOrder>(object::object_address(fusion_order_obj))
    }

    /// Borrows a mutable reference to the FusionOrder.
    ///
    /// @param fusion_order_obj The fusion order object.
    /// @return &mut FusionOrder Mutable reference to the fusion order.
    inline fun borrow_fusion_order_mut(
        fusion_order_obj: &Object<FusionOrder>
    ): &mut FusionOrder acquires FusionOrder {
        borrow_global_mut<FusionOrder>(object::object_address(fusion_order_obj))
    }

    // - - - - TEST FUNCTIONS - - - -

    #[test_only]
    friend aptos_fusion_plus::fusion_order_tests;

    #[test_only]
    /// Deletes a fusion order for testing purposes.
    /// Burns the assets instead of returning them to simulate order pickup.
    ///
    /// @param fusion_order The fusion order to delete.
    public fun delete_for_test(
        fusion_order: Object<FusionOrder>
    ) acquires FusionOrder, FusionOrderController {
        let object_address = object::object_address(&fusion_order);
        let FusionOrderController { extend_ref, delete_ref } = move_from(object_address);
        let object_signer = object::generate_signer_for_extending(&extend_ref);

        let fusion_order_ref = borrow_fusion_order_mut(&fusion_order);

        let burn_address = @0x0;
        primary_fungible_store::transfer(
            &object_signer,
            fusion_order_ref.metadata,
            burn_address,
            fusion_order_ref.amount
        );

        primary_fungible_store::transfer(
            &object_signer,
            fusion_order_ref.safety_deposit_metadata,
            burn_address,
            fusion_order_ref.safety_deposit_amount
        );
        object::delete(delete_ref);
    }
}
