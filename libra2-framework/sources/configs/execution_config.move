/// Maintains the execution config for the blockchain. The config is stored in a
/// Reconfiguration, and may be updated by root.
module libra2_framework::execution_config {
    use libra2_framework::config_buffer;
    use std::error;
    use std::vector;
    use libra2_framework::chain_status;

    use libra2_framework::reconfiguration;
    use libra2_framework::system_addresses;
    friend libra2_framework::genesis;
    friend libra2_framework::reconfiguration_with_dkg;

    struct ExecutionConfig has drop, key, store {
        config: vector<u8>,
    }

    /// The provided on chain config bytes are empty or invalid
    const EINVALID_CONFIG: u64 = 1;

    /// Deprecated by `set_for_next_epoch()`.
    ///
    /// WARNING: calling this while randomness is enabled will trigger a new epoch without randomness!
    ///
    /// TODO: update all the tests that reference this function, then disable this function.
    public fun set(account: &signer, config: vector<u8>) acquires ExecutionConfig {
        system_addresses::assert_libra2_framework(account);
        chain_status::assert_genesis();

        assert!(vector::length(&config) > 0, error::invalid_argument(EINVALID_CONFIG));

        if (exists<ExecutionConfig>(@libra2_framework)) {
            let config_ref = &mut borrow_global_mut<ExecutionConfig>(@libra2_framework).config;
            *config_ref = config;
        } else {
            move_to(account, ExecutionConfig { config });
        };
        // Need to trigger reconfiguration so validator nodes can sync on the updated configs.
        reconfiguration::reconfigure();
    }

    /// This can be called by on-chain governance to update on-chain execution configs for the next epoch.
    /// Example usage:
    /// ```
    /// libra2_framework::execution_config::set_for_next_epoch(&framework_signer, some_config_bytes);
    /// libra2_framework::libra2_governance::reconfigure(&framework_signer);
    /// ```
    public fun set_for_next_epoch(account: &signer, config: vector<u8>) {
        system_addresses::assert_libra2_framework(account);
        assert!(vector::length(&config) > 0, error::invalid_argument(EINVALID_CONFIG));
        config_buffer::upsert(ExecutionConfig { config });
    }

    /// Only used in reconfigurations to apply the pending `ExecutionConfig`, if there is any.
    public(friend) fun on_new_epoch(framework: &signer) acquires ExecutionConfig {
        system_addresses::assert_libra2_framework(framework);
        if (config_buffer::does_exist<ExecutionConfig>()) {
            let config = config_buffer::extract<ExecutionConfig>();
            if (exists<ExecutionConfig>(@libra2_framework)) {
                *borrow_global_mut<ExecutionConfig>(@libra2_framework) = config;
            } else {
                move_to(framework, config);
            };
        }
    }
}
