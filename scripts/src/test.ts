import { Aptos, AptosConfig, Network, Ed25519PrivateKey, Account } from "@aptos-labs/ts-sdk";
import { FusionPlusClient } from "./fusion-plus-client";
const dotenv = require('dotenv');
// Load environment variables
dotenv.config({ path: '../../.env' });

// Configuration from environment variables
const NETWORK = (process.env.NETWORK as Network) || Network.TESTNET;
const CONTRACT_ADDRESS_TESTNET = process.env.CONTRACT_ADDRESS_TESTNET || "0xd4d479bbcad621f806f2ed82aae05c6bcb98b01c02a056933d074729f4872192";
const CONTRACT_ADDRESS_DEVNET = process.env.CONTRACT_ADDRESS_DEVNET || "0xa39c90ee66e21c276192abcb0bd02b6e791b6f13f9b51c272aa4c70f4eb99e50";

// Private keys from environment variables
const OWNER_PRIVATE_KEY = process.env.OWNER_PRIVATE_KEY as string;
const RESOLVER_PRIVATE_KEY = process.env.RESOLVER_PRIVATE_KEY as string;
const USER_PRIVATE_KEY = process.env.USER_PRIVATE_KEY as string;

// Configuration flags
const ENABLE_RESOLVER_REGISTRATION = process.env.ENABLE_RESOLVER_REGISTRATION === 'true';
const ENABLE_FAUCET_FUNDING = process.env.ENABLE_FAUCET_FUNDING === 'true';

// Validate required environment variables
function validateEnvironmentVariables() {
  const requiredVars = [
    'CONTRACT_ADDRESS_TESTNET',
    'CONTRACT_ADDRESS_DEVNET', 
    'OWNER_PRIVATE_KEY',
    'RESOLVER_PRIVATE_KEY',
    'USER_PRIVATE_KEY'
  ];
  
  const missingVars = requiredVars.filter(varName => !process.env[varName]);
  
  if (missingVars.length > 0) {
    console.error('❌ Missing required environment variables:');
    missingVars.forEach(varName => console.error(`   - ${varName}`));
    console.error('\n📝 Please create a .env file with the required variables:');
    console.error('   cp .example.env .env');
    console.error('   # Then edit .env with your values');
    process.exit(1);
  }
}

// Validate environment variables
validateEnvironmentVariables();

// Deployments configuration
const DEPLOYMENTS = {
  testnet: {
    address: CONTRACT_ADDRESS_TESTNET,
    explorer: `https://explorer.aptoslabs.com/account/${CONTRACT_ADDRESS_TESTNET}/modules/packages/aptos_fusion_plus?network=testnet`
  },
  devnet: {
    address: CONTRACT_ADDRESS_DEVNET,
    explorer: `https://explorer.aptoslabs.com/account/${CONTRACT_ADDRESS_DEVNET}/modules/packages/aptos_fusion_plus?network=devnet`
  }
};

console.log("🧪 Starting Aptos Fusion Plus Contract Tests");

// Initialize Aptos client
const config = new AptosConfig({ network: NETWORK });
const aptos = new Aptos(config);

// Create accounts from private keys
const ownerPrivateKey = new Ed25519PrivateKey(OWNER_PRIVATE_KEY);
const resolverPrivateKey = new Ed25519PrivateKey(RESOLVER_PRIVATE_KEY);
const userPrivateKey = new Ed25519PrivateKey(USER_PRIVATE_KEY);

const owner = Account.fromPrivateKey({ privateKey: ownerPrivateKey });
const resolver = Account.fromPrivateKey({ privateKey: resolverPrivateKey });
const user = Account.fromPrivateKey({ privateKey: userPrivateKey });

console.log(`📝 Owner address: ${owner.accountAddress}`);
console.log(`📝 Resolver address: ${resolver.accountAddress}`);
console.log(`📝 User address: ${user.accountAddress}`);

// Initialize FusionPlusClient
const fusionClient = new FusionPlusClient(aptos, DEPLOYMENTS.testnet.address);

async function runTests() {
  // Note: For testnet, accounts need to be funded manually via https://aptos.dev/network/faucet
  console.log("💰 Note: For testnet, accounts need to be funded manually via https://aptos.dev/network/faucet");
  console.log("💰 Testing with existing accounts that should have funds...");
  
  // Run tests
  await testContractInfo(fusionClient);
  // Skip resolver registration since it's already registered
  console.log("\n📝 Skipping resolver registration (already registered)...");
  const orderTxnHash = await testFusionOrderCreation(fusionClient, user);
  if (orderTxnHash) {
    await testAcceptFusionOrder(fusionClient, resolver, orderTxnHash);
  } else {
    console.log("⚠️ Skipping fusion order acceptance test due to failed order creation");
  }
  const escrowTxnHash = await testEscrowCreation(fusionClient, resolver);
  if (escrowTxnHash) {
    await testEscrowWithdraw(fusionClient, resolver, escrowTxnHash);
  } else {
    console.log("⚠️ Skipping escrow withdraw test due to failed escrow creation");
  }
  
  console.log("✅ All tests completed!");
}

async function testContractInfo(fusionClient: FusionPlusClient) {
  console.log("\n📊 Testing Contract Info...");
  
  try {
    const contractInfo = await fusionClient.getContractInfo();
    console.log("Contract info:", contractInfo);
    
    const resources = await fusionClient.getContractResources();
    console.log(`Found ${resources.length} resources`);
    
    console.log("✅ Contract info test passed");
  } catch (error) {
    console.error("❌ Contract info test failed:", error);
  }
}

async function testFusionOrderCreation(fusionClient: FusionPlusClient, user: Account) {
  console.log("\n🔥 Testing Fusion Order Creation...");
  
  try {
    // Test fusion order creation with real parameters from Explorer_params.md
    console.log("Testing fusion order creation...");
    
    // APT metadata (0xa for APT)
    const aptMetadata = "0xa";
    
    // Destination asset (native asset - all zeros)
    const destinationAsset = new Array(32).fill(0);
    
    // Destination recipient (EVM address - 20 bytes)
    const destinationRecipient = [
      116, 45, 53, 204, 102, 52, 192, 83, 41, 37, 
      163, 184, 212, 201, 219, 150, 196, 180, 139, 119
    ];
    
    // Hash for cross-chain verification (32 bytes)
    const hash = [
      18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
      52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
    ];
    
    const createOrderPayload = fusionClient.buildTransactionPayload(
      "fusion_order::new_entry",
      [],
      [
        aptMetadata, // source_metadata
        1000000, // source_amount (1 APT)
        destinationAsset, // destination_asset
        destinationRecipient, // destination_recipient
        137, // chain_id (Polygon)
        hash, // hash
        1000000, // initial_destination_amount
        900000, // min_destination_amount
        100, // decay_per_second
      ]
    );
    
    console.log("Created fusion order payload:", createOrderPayload);
    
    // Submit the transaction
    console.log("Submitting fusion order creation transaction...");
    const txn = await fusionClient.submitTransaction(user, createOrderPayload);
    console.log("Fusion order creation transaction:", txn.hash);
    
    console.log("✅ Fusion order creation test completed");
    return txn.hash; // Return the transaction hash for later use
  } catch (error) {
    console.error("❌ Fusion order creation test failed:", error);
    return null;
  }
}

async function getFusionOrderObjectAddress(contractAddress: string, transactionHash?: string): Promise<string | null> {
  console.log("🔍 Getting fusion order object address from events...");
  
  try {
    const fullnodeUrl = "https://api.testnet.aptoslabs.com/v1";
    
    // If we have a transaction hash, try to get events from that specific transaction
    if (transactionHash) {
      console.log("🔍 Trying to get events from specific transaction...");
      const txnResponse = await fetch(`${fullnodeUrl}/transactions/by_hash/${transactionHash}`);
      
      if (txnResponse.ok) {
        const txn = await txnResponse.json();
        console.log(`📡 Found transaction with ${txn.events?.length || 0} events`);
        
        if (txn.events) {
          for (const event of txn.events) {
            console.log(`Event type: ${event.type}`);
            
            if (event.type && event.type.includes("FusionOrderCreatedEvent")) {
              console.log("🔥 Found FusionOrderCreatedEvent in transaction!");
              console.log("Event data:", JSON.stringify(event.data, null, 2));
              
              if (event.data && event.data.fusion_order) {
                let fusionOrderAddress = event.data.fusion_order;
                
                // Handle different possible formats
                if (typeof fusionOrderAddress === 'object' && fusionOrderAddress.inner) {
                  fusionOrderAddress = fusionOrderAddress.inner;
                } else if (typeof fusionOrderAddress === 'string') {
                  // Already a string
                } else {
                  fusionOrderAddress = JSON.stringify(fusionOrderAddress);
                }
                
                console.log("📝 Extracted fusion order address from transaction:", fusionOrderAddress);
                return fusionOrderAddress;
              }
            }
          }
        }
      }
    }
    
    // If not found in transaction events, try to get events from the contract address
    console.log("🔍 Trying to get events from contract address...");
    const response = await fetch(`${fullnodeUrl}/accounts/${contractAddress}/events?limit=10`);
    
    if (!response.ok) {
      console.log("❌ Failed to fetch events from contract address");
      return null;
    }
    
    const events = await response.json();
    console.log(`📡 Found ${events.length} events from contract`);
    
    // Look for FusionOrderCreatedEvent
    for (const event of events) {
      console.log(`Event type: ${event.type}`);
      
      if (event.type && event.type.includes("FusionOrderCreatedEvent")) {
        console.log("🔥 Found FusionOrderCreatedEvent!");
        console.log("Event data:", JSON.stringify(event.data, null, 2));
        
        if (event.data && event.data.fusion_order) {
          let fusionOrderAddress = event.data.fusion_order;
          
          // Handle different possible formats
          if (typeof fusionOrderAddress === 'object' && fusionOrderAddress.inner) {
            fusionOrderAddress = fusionOrderAddress.inner;
          } else if (typeof fusionOrderAddress === 'string') {
            // Already a string
          } else {
            fusionOrderAddress = JSON.stringify(fusionOrderAddress);
          }
          
          console.log("📝 Extracted fusion order address:", fusionOrderAddress);
          return fusionOrderAddress;
        }
      }
    }
    
    console.log("❌ No FusionOrderCreatedEvent found in events");
    return null;
    
  } catch (error) {
    console.error("❌ Error fetching events:", error);
    return null;
  }
}

async function testAcceptFusionOrder(fusionClient: FusionPlusClient, resolver: Account, orderTxnHash: string) {
  console.log("\n🤝 Testing Accept Fusion Order...");
  
  try {
    // Get the real fusion order object address from events
    const fusionOrderObjectAddress = await getFusionOrderObjectAddress(DEPLOYMENTS.testnet.address, orderTxnHash);
    
    if (!fusionOrderObjectAddress) {
      console.log("⚠️ Could not get fusion order address from events, using placeholder...");
      const placeholderAddress = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      console.log("📝 Using placeholder fusion order object address:", placeholderAddress);
      
      const acceptOrderPayload = fusionClient.buildTransactionPayload(
        "escrow::new_from_order_entry",
        [],
        [
          placeholderAddress, // fusion_order object address
        ]
      );
      
      console.log("Created accept order payload:", acceptOrderPayload);
      
      // Submit the transaction
      console.log("Submitting fusion order acceptance transaction...");
      const txn = await fusionClient.submitTransaction(resolver, acceptOrderPayload);
      console.log("Fusion order acceptance transaction:", txn.hash);
      
      console.log("✅ Fusion order acceptance test completed (with placeholder)");
      return;
    }
    
    console.log("📝 Using real fusion order object address:", fusionOrderObjectAddress);
    
    const acceptOrderPayload = fusionClient.buildTransactionPayload(
      "escrow::new_from_order_entry",
      [],
      [
        fusionOrderObjectAddress, // real fusion_order object address
      ]
    );
    
    console.log("Created accept order payload:", acceptOrderPayload);
    
    // Submit the transaction
    console.log("Submitting fusion order acceptance transaction...");
    const txn = await fusionClient.submitTransaction(resolver, acceptOrderPayload);
    console.log("Fusion order acceptance transaction:", txn.hash);
    
    console.log("✅ Fusion order acceptance test completed (with real address)");
  } catch (error) {
    console.error("❌ Fusion order acceptance test failed:", error);
  }
}

async function testEscrowCreation(fusionClient: FusionPlusClient, resolver: Account) {
  console.log("\n🔒 Testing Escrow Creation...");
  
  try {
    // Test escrow creation with real parameters
    console.log("Testing escrow creation...");
    
    // Convert recipient address to proper format (pad to 64 characters)
    const recipientAddress = "0x" + "742d35cc6634c0532925a3b8d4c9db96c4b48b77".padStart(64, '0');
    
    const hash = [
      18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
      52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
    ];
    
    const createEscrowPayload = fusionClient.buildTransactionPayload(
      "escrow::new_from_resolver_entry",
      [],
      [
        recipientAddress, // recipient_address as string (padded to 64 chars)
        "0xa", // metadata (APT)
        950000, // amount
        137, // chain_id (Polygon)
        hash, // hash
      ]
    );
    
    console.log("Created escrow payload:", createEscrowPayload);
    
    // Submit the transaction
    console.log("Submitting escrow creation transaction...");
    const txn = await fusionClient.submitTransaction(resolver, createEscrowPayload);
    console.log("Escrow creation transaction:", txn.hash);
    
    console.log("✅ Escrow creation test completed");
    return txn.hash; // Return the transaction hash for later use
  } catch (error) {
    console.error("❌ Escrow creation test failed:", error);
    return null;
  }
}

async function getEscrowObjectAddress(contractAddress: string, transactionHash?: string): Promise<string | null> {
  console.log("🔍 Getting escrow object address from events...");
  
  try {
    const fullnodeUrl = "https://api.testnet.aptoslabs.com/v1";
    
    // If we have a transaction hash, try to get events from that specific transaction
    if (transactionHash) {
      console.log("🔍 Trying to get events from specific transaction...");
      const txnResponse = await fetch(`${fullnodeUrl}/transactions/by_hash/${transactionHash}`);
      
      if (txnResponse.ok) {
        const txn = await txnResponse.json();
        console.log(`📡 Found transaction with ${txn.events?.length || 0} events`);
        
        if (txn.events) {
          for (const event of txn.events) {
            console.log(`Event type: ${event.type}`);
            
            if (event.type && event.type.includes("EscrowCreatedEvent")) {
              console.log("🔒 Found EscrowCreatedEvent in transaction!");
              console.log("Event data:", JSON.stringify(event.data, null, 2));
              
              if (event.data && event.data.escrow) {
                let escrowAddress = event.data.escrow;
                
                // Handle different possible formats
                if (typeof escrowAddress === 'object' && escrowAddress.inner) {
                  escrowAddress = escrowAddress.inner;
                } else if (typeof escrowAddress === 'string') {
                  // Already a string
                } else {
                  escrowAddress = JSON.stringify(escrowAddress);
                }
                
                console.log("📝 Extracted escrow address from transaction:", escrowAddress);
                return escrowAddress;
              }
            }
          }
        }
      }
    }
    
    // If not found in transaction events, try to get events from the contract address
    console.log("🔍 Trying to get events from contract address...");
    const response = await fetch(`${fullnodeUrl}/accounts/${contractAddress}/events?limit=10`);
    
    if (!response.ok) {
      console.log("❌ Failed to fetch events from contract address");
      return null;
    }
    
    const events = await response.json();
    console.log(`📡 Found ${events.length} events from contract`);
    
    // Look for EscrowCreatedEvent
    for (const event of events) {
      console.log(`Event type: ${event.type}`);
      
      if (event.type && event.type.includes("EscrowCreatedEvent")) {
        console.log("🔒 Found EscrowCreatedEvent!");
        console.log("Event data:", JSON.stringify(event.data, null, 2));
        
        if (event.data && event.data.escrow) {
          let escrowAddress = event.data.escrow;
          
          // Handle different possible formats
          if (typeof escrowAddress === 'object' && escrowAddress.inner) {
            escrowAddress = escrowAddress.inner;
          } else if (typeof escrowAddress === 'string') {
            // Already a string
          } else {
            escrowAddress = JSON.stringify(escrowAddress);
          }
          
          console.log("📝 Extracted escrow address:", escrowAddress);
          return escrowAddress;
        }
      }
    }
    
    console.log("❌ No EscrowCreatedEvent found in events");
    return null;
    
  } catch (error) {
    console.error("❌ Error fetching events:", error);
    return null;
  }
}

async function testEscrowWithdraw(fusionClient: FusionPlusClient, resolver: Account, escrowTxnHash: string) {
  console.log("\n💸 Testing Escrow Withdraw...");
  
  try {
    // Get the real escrow object address from events
    const escrowObjectAddress = await getEscrowObjectAddress(DEPLOYMENTS.testnet.address, escrowTxnHash);
    
    if (!escrowObjectAddress) {
      console.log("⚠️ Could not get escrow address from events, using placeholder...");
      const placeholderAddress = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      console.log("📝 Using placeholder escrow object address:", placeholderAddress);
      
      // The secret that matches the hashlock (this should be the preimage of the hash)
      // In a real scenario, this would be the actual secret used to create the hashlock
      const secret = [
        18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
        52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
      ];
      
      const withdrawPayload = fusionClient.buildTransactionPayload(
        "escrow::withdraw",
        [],
        [
          placeholderAddress, // escrow object address
          secret, // secret to verify against hashlock
        ]
      );
      
      console.log("Created withdraw payload:", withdrawPayload);
      
      // Submit the transaction
      console.log("Submitting escrow withdraw transaction...");
      const txn = await fusionClient.submitTransaction(resolver, withdrawPayload);
      console.log("Escrow withdraw transaction:", txn.hash);
      
      console.log("✅ Escrow withdraw test completed (with placeholder)");
      return;
    }
    
    console.log("📝 Using real escrow object address:", escrowObjectAddress);
    
    // The secret that matches the hashlock (this should be the preimage of the hash)
    // In a real scenario, this would be the actual secret used to create the hashlock
    const secret = [
      18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 
      52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52, 86, 120, 144, 18, 52
    ];
    
    const withdrawPayload = fusionClient.buildTransactionPayload(
      "escrow::withdraw",
      [],
      [
        escrowObjectAddress, // real escrow object address
        secret, // secret to verify against hashlock
      ]
    );
    
    console.log("Created withdraw payload:", withdrawPayload);
    
    // Submit the transaction
    console.log("Submitting escrow withdraw transaction...");
    const txn = await fusionClient.submitTransaction(resolver, withdrawPayload);
    console.log("Escrow withdraw transaction:", txn.hash);
    
    console.log("✅ Escrow withdraw test completed (with real address)");
  } catch (error) {
    console.error("❌ Escrow withdraw test failed:", error);
  }
}

// Run tests
runTests().catch(console.error); 