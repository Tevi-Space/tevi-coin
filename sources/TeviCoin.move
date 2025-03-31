/// A module that implements the Tevi Coin as a managed fungible asset with the following features:
/// - Fixed maximum supply of 100 billion tokens (with 8 decimals)
/// - Minting controlled by the admin (gradual minting up to max supply)
/// - Ability to pause all transfers
/// - Ability to freeze/unfreeze specific accounts
/// - Burning capability
/// - Primary store support for easy token management
///
module TeviCoin::TeviCoin {
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::function_info;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::event;
    use std::error;
    use std::signer;
    use std::string::{Self, utf8};
    use std::option;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;
    /// The Tevi Coin is paused.
    const EPAUSED: u64 = 2;

    const ASSET_SYMBOL: vector<u8> = b"TEVI";
    const DECIMALS: u8 = 8;
    
    /// Total supply of 100 billion tokens with 8 decimals (100_000_000_000 * 10^8)
    const TOTAL_SUPPLY: u128 = 100_000_000_000_0000_0000;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Global state to pause the Tevi Coin.
    /// OPTIONAL
    struct State has key {
        paused: bool,
    }

    #[event]
    struct MintEvent has drop, store {
        admin: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct BurnEvent has drop, store {
        admin: address,
        from: address,
        amount: u64,
    }

    #[event]
    struct TransferEvent has drop, store {
        admin: address,
        from: address,
        to: address,
        amount: u64,
    }

    #[event]
    struct FreezeAccountEvent has drop, store {
        admin: address,
        account: address,
    }

    #[event]
    struct UnfreezeAccountEvent has drop, store {
        admin: address,
        account: address,
    }

    #[event]
    struct SetPauseEvent has drop, store {
        admin: address,
        paused: bool,
    }

    /// Initialize metadata object and store the refs.
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::some(TOTAL_SUPPLY),
            utf8(b"TEVI Coin"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            DECIMALS, /* decimals */
            utf8(b"https://static.tevi.app/coin/TEVI.svg"), /* icon */
            utf8(b"https://tevi.com/"), /* project */
        );

        // Create mint/burn/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        );

        // Create a global state to pause the Tevi Coin and move to Metadata object.
        move_to(
            &metadata_object_signer,
            State { paused: false, }
        );

        // Override the deposit and withdraw functions which mean overriding transfer.
        // This ensures all transfer will call withdraw and deposit functions in this module
        // and perform the necessary checks.
        // This is OPTIONAL. It is an advanced feature and we don't NEED a global state to pause the Tevi Coin.
        let deposit = function_info::new_function_info(
            admin,
            string::utf8(b"TeviCoin"),
            string::utf8(b"deposit"),
        );
        let withdraw = function_info::new_function_info(
            admin,
            string::utf8(b"TeviCoin"),
            string::utf8(b"withdraw"),
        );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none(),
        );
    }

    #[view]
    /// Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@TeviCoin, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    /// Deposit function override to ensure that the account is not denylisted and the Tevi Coin is not paused.
    /// OPTIONAL
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) acquires State {
        assert_not_paused();
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    /// Withdraw function override to ensure that the account is not denylisted and the Tevi Coin is not paused.
    /// OPTIONAL
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &TransferRef,
    ): FungibleAsset acquires State {
        assert_not_paused();
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    /// Mint as the owner of metadata object.
    public entry fun mint(admin: &signer, to: address, amount: u64) acquires ManagedFungibleAsset {
        let admin_addr = signer::address_of(admin);
        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(admin, asset);
        
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
        
        // Emit mint event
        event::emit(MintEvent {
            admin: admin_addr,
            to,
            amount,
        });
    }

    /// Transfer as the owner of metadata object ignoring `frozen` field.
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset, State {
        let admin_addr = signer::address_of(admin);
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = withdraw(from_wallet, amount, transfer_ref);
        deposit(to_wallet, fa, transfer_ref);

        // Emit transfer event
        event::emit(TransferEvent {
            admin: admin_addr,
            from,
            to,
            amount,
        });
    }

    /// Burn fungible assets as the owner of metadata object.
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset {
        let admin_addr = signer::address_of(admin);
        let asset = get_metadata();
        let burn_ref = &authorized_borrow_refs(admin, asset).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);

        // Emit burn event
        event::emit(BurnEvent {
            admin: admin_addr,
            from,
            amount,
        });
    }

    /// Freeze an account so it cannot transfer or receive fungible assets.
    public entry fun freeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let admin_addr = signer::address_of(admin);
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, true);

        // Emit freeze account event
        event::emit(FreezeAccountEvent {
            admin: admin_addr,
            account,
        });
    }

    /// Unfreeze an account so it can transfer or receive fungible assets.
    public entry fun unfreeze_account(admin: &signer, account: address) acquires ManagedFungibleAsset {
        let admin_addr = signer::address_of(admin);
        let asset = get_metadata();
        let transfer_ref = &authorized_borrow_refs(admin, asset).transfer_ref;
        let wallet = primary_fungible_store::ensure_primary_store_exists(account, asset);
        fungible_asset::set_frozen_flag(transfer_ref, wallet, false);

        // Emit unfreeze account event
        event::emit(UnfreezeAccountEvent {
            admin: admin_addr,
            account,
        });
    }

    /// Pause or unpause the transfer of Tevi Coin. This checks that the caller is the pauser.
    public entry fun set_pause(pauser: &signer, paused: bool) acquires State {
        let pauser_addr = signer::address_of(pauser);
        let asset = get_metadata();
        assert!(object::is_owner(asset, pauser_addr), error::permission_denied(ENOT_OWNER));
        let state = borrow_global_mut<State>(object::create_object_address(&@TeviCoin, ASSET_SYMBOL));
        if (state.paused == paused) { return };
        state.paused = paused;

        // Emit set pause event
        event::emit(SetPauseEvent {
            admin: pauser_addr,
            paused,
        });
    }

    /// Assert that the Tevi Coin is not paused.
    /// OPTIONAL
    fun assert_not_paused() acquires State {
        let state = borrow_global<State>(object::create_object_address(&@TeviCoin, ASSET_SYMBOL));
        assert!(!state.paused, EPAUSED);
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, signer::address_of(owner)), error::permission_denied(ENOT_OWNER));
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }

    #[test_only]
    /// Helper function to setup a test environment and return common test values
    public fun initialize_for_test(creator: &signer) {
        init_module(creator);
    }

    #[test_only]
    /// Helper function to setup a test environment and return common test values
    public fun setup_test(creator: &signer): (address, Object<Metadata>) {
        init_module(creator);
        let creator_address = signer::address_of(creator);
        let asset = get_metadata();
        (creator_address, asset)
    }
}