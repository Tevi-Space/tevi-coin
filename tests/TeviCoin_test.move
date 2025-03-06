#[test_only]
module TeviCoin::TeviCoin_test {
    use TeviCoin::TeviCoin;
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use std::option;

    #[test(creator = @TeviCoin)]
    /// Test basic token operations: mint, freeze, transfer, unfreeze, and burn
    fun test_basic_flow(
        creator: &signer,
    ) {
        let (creator_address, asset) = TeviCoin::setup_test(creator);
        let aaron_address = @0xface;

        // Test minting
        let mint_amount = 10000;
        TeviCoin::mint(creator, creator_address, mint_amount);
        assert!(primary_fungible_store::balance(creator_address, asset) == mint_amount, 1);
        
        // Test freezing
        TeviCoin::freeze_account(creator, creator_address);
        assert!(primary_fungible_store::is_frozen(creator_address, asset), 2);
        
        // Test transfer
        let transfer_amount = 1000;
        TeviCoin::transfer(creator, creator_address, aaron_address, transfer_amount);
        assert!(primary_fungible_store::balance(aaron_address, asset) == transfer_amount, 3);
        assert!(primary_fungible_store::balance(creator_address, asset) == mint_amount - transfer_amount, 4);

        // Test unfreezing
        TeviCoin::unfreeze_account(creator, creator_address);
        assert!(!primary_fungible_store::is_frozen(creator_address, asset), 5);
        
        // Test burning
        let burn_amount = 1000;
        TeviCoin::burn(creator, creator_address, burn_amount);
        assert!(primary_fungible_store::balance(creator_address, asset) == mint_amount - transfer_amount - burn_amount, 6);
    }

    #[test(creator = @TeviCoin)]
    /// Test initialization with zero supply and verify supply tracking
    fun test_total_supply_initialization(creator: &signer) {
        let (creator_address, asset) = TeviCoin::setup_test(creator);
        
        // Verify initial zero supply
        let current_supply = fungible_asset::supply(asset);
        assert!(option::is_some(&current_supply), 1);
        assert!(*option::borrow(&current_supply) == 0, 2);

        // Test minting up to total supply
        TeviCoin::mint(creator, creator_address, 100_000_000_000_0000_0000);
        current_supply = fungible_asset::supply(asset);
        assert!(*option::borrow(&current_supply) == (100_000_000_000_0000_0000 as u128), 3);
    }

    #[test(creator = @TeviCoin)]
    #[expected_failure(abort_code = 0x30003, location = TeviCoin)]
    /// Test that minting beyond total supply fails
    fun test_mint_exceeds_total_supply(creator: &signer) {
        let (creator_address, _) = TeviCoin::setup_test(creator);
        
        // Mint total supply
        TeviCoin::mint(creator, creator_address, 100_000_000_000_0000_0000);
        
        // Attempt to mint beyond total supply - should fail
        TeviCoin::mint(creator, creator_address, 1);
    }

    #[test(creator = @TeviCoin)]
    /// Test burn and remint functionality within supply limits
    fun test_burn_and_remint(creator: &signer) {
        let (creator_address, asset) = TeviCoin::setup_test(creator);
        
        // Test initial minting
        let initial_amount = 10000000;
        TeviCoin::mint(creator, creator_address, initial_amount);
        assert!(primary_fungible_store::balance(creator_address, asset) == initial_amount, 1);
        
        // Test burning
        let burn_amount = 1000000;
        TeviCoin::burn(creator, creator_address, burn_amount);
        assert!(primary_fungible_store::balance(creator_address, asset) == initial_amount - burn_amount, 2);
        
        // Test reminting of burned amount
        TeviCoin::mint(creator, creator_address, burn_amount);
        assert!(primary_fungible_store::balance(creator_address, asset) == initial_amount, 3);
    }

    #[test(creator = @TeviCoin, aaron = @0xface)]
    #[expected_failure(abort_code = 0x50001, location = TeviCoin)]
    /// Test that non-owners cannot mint tokens
    fun test_permission_denied(
        creator: &signer,
        aaron: &signer
    ) {
        let (creator_address, _) = TeviCoin::setup_test(creator);
        TeviCoin::mint(aaron, creator_address, 100);
    }

    #[test(creator = @TeviCoin)]
    #[expected_failure(abort_code = 0x2, location = TeviCoin)]
    /// Test that transfers fail when coin is paused
    fun test_paused(
        creator: &signer,
    ) {
        let (creator_address, _) = TeviCoin::setup_test(creator);
        let aaron_address = @0xface;
        
        // Setup initial balance
        TeviCoin::mint(creator, creator_address, 10000);
        
        // Test transfer fails when paused
        TeviCoin::set_pause(creator, true);
        TeviCoin::transfer(creator, creator_address, aaron_address, 1000);
    }
} 