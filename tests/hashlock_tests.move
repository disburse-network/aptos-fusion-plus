#[test_only]
module aptos_fusion_plus::hashlock_tests {
    use std::vector;
    use std::hash;
    use aptos_fusion_plus::hashlock;

    // Test constants
    const TEST_SECRET: vector<u8> = b"my secret";
    const WRONG_SECRET: vector<u8> = b"wrong secret";
    const INVALID_HASH: vector<u8> = b"too short";

    #[test]
    fun test_create_hashlock() {
        let test_hash = hash::sha3_256(TEST_SECRET);
        let hashlock = hashlock::create_hashlock(test_hash);
        assert!(hashlock::get_hash(&hashlock) == test_hash, 0);
    }

    #[test]
    fun test_verify_hashlock() {
        let hashlock = hashlock::create_hashlock_for_test(TEST_SECRET);
        assert!(hashlock::verify_hashlock(&hashlock, TEST_SECRET), 0);
        assert!(!hashlock::verify_hashlock(&hashlock, WRONG_SECRET), 0);
    }

    #[test]
    #[expected_failure(abort_code = hashlock::EINVALID_HASH)]
    fun test_create_hashlock_invalid_hash() {
        // Try to create hashlock with invalid hash length
        hashlock::create_hashlock(INVALID_HASH);
    }

    #[test]
    #[expected_failure(abort_code = hashlock::EINVALID_SECRET)]
    fun test_verify_hashlock_empty_secret() {
        let hashlock = hashlock::create_hashlock_for_test(TEST_SECRET);
        hashlock::verify_hashlock(&hashlock, vector::empty());
    }

    #[test]
    fun test_is_valid_secret() {
        // Test valid secrets
        assert!(hashlock::is_valid_secret(&TEST_SECRET), 0);
        assert!(hashlock::is_valid_secret(&vector::singleton(1u8)), 0);
        
        // Test invalid secrets
        assert!(!hashlock::is_valid_secret(&vector::empty()), 0);
    }

    #[test]
    fun test_is_valid_hash() {
        let valid_hash = hash::sha3_256(TEST_SECRET);
        let invalid_hash = vector::empty();
        
        // Test valid hash
        assert!(hashlock::is_valid_hash(&valid_hash), 0);
        
        // Test invalid hash
        assert!(!hashlock::is_valid_hash(&invalid_hash), 0);
        assert!(!hashlock::is_valid_hash(&INVALID_HASH), 0);
    }

    #[test]
    fun test_create_hash_for_test() {
        let secret = b"test_secret";
        let hash = hashlock::create_hash_for_test(secret);
        
        // Verify hash is correct length
        assert!(vector::length(&hash) == 32, 0);
        
        // Verify hash matches expected
        assert!(hash == hash::sha3_256(secret), 0);
    }

    #[test]
    fun test_hashlock_very_long_secret() {
        // Create a very long secret
        let long_secret = vector::empty<u8>();
        let i = 0;
        while (i < 1000) {
            vector::push_back(&mut long_secret, 255u8);
            i = i + 1;
        };
        
        // Should still work
        let hashlock = hashlock::create_hashlock_for_test(long_secret);
        assert!(hashlock::verify_hashlock(&hashlock, long_secret), 0);
    }

    #[test]
    fun test_hashlock_minimum_secret() {
        // Test minimum valid secret (1 byte)
        let min_secret = vector::singleton(42u8);
        let hashlock = hashlock::create_hashlock_for_test(min_secret);
        assert!(hashlock::verify_hashlock(&hashlock, min_secret), 0);
    }

    #[test]
    #[expected_failure(abort_code = hashlock::EINVALID_SECRET)]
    fun test_create_hashlock_for_test_empty_secret() {
        // Test that empty secret fails
        hashlock::create_hashlock_for_test(vector::empty());
    }

    #[test]
    fun test_hashlock_boundary_hash_length() {
        // Test exactly 32-byte hash
        let exact_hash = vector::empty<u8>();
        let i = 0;
        while (i < 32) {
            vector::push_back(&mut exact_hash, 255u8);
            i = i + 1;
        };
        
        let hashlock = hashlock::create_hashlock(exact_hash);
        assert!(hashlock::get_hash(&hashlock) == exact_hash, 0);
    }
}
