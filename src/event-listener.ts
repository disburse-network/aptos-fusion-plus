import { Aptos, Event } from "@aptos-labs/ts-sdk";

export class EventListener {
  private aptos: Aptos;
  private contractAddress: string;
  private isListening: boolean = false;
  private eventHandlers: Map<string, (event: Event) => void> = new Map();
  private lastSequenceNumbers: Map<string, number> = new Map();

  constructor(aptos: Aptos, contractAddress: string) {
    this.aptos = aptos;
    this.contractAddress = contractAddress;
  }

  /**
   * Start listening to events from the contract
   */
  async startListening() {
    if (this.isListening) {
      console.log("Event listener is already running");
      return;
    }

    this.isListening = true;
    console.log(`🎧 Starting event listener for contract: ${this.contractAddress}`);

    // Set up event handlers for different event types
    this.setupEventHandlers();

    // Start polling for events
    this.pollEvents();
  }

  /**
   * Stop listening to events
   */
  stopListening() {
    this.isListening = false;
    console.log("🛑 Stopped event listener");
  }

  /**
   * Set up handlers for different event types based on actual contract events
   */
  private setupEventHandlers() {
    // Fusion Order Events
    this.eventHandlers.set("FusionOrderCreatedEvent", (event) => {
      console.log("🔥 Fusion Order Created:");
      console.log(`   Order: ${event.data.fusion_order}`);
      console.log(`   Owner: ${event.data.owner}`);
      console.log(`   Source Amount: ${event.data.source_amount}`);
      console.log(`   Chain ID: ${event.data.chain_id}`);
      console.log(`   Initial Price: ${event.data.initial_destination_amount}`);
      console.log(`   Min Price: ${event.data.min_destination_amount}`);
      console.log(`   Decay Rate: ${event.data.decay_per_second}`);
      console.log(`   Current Price: ${event.data.current_price}`);
    });

    this.eventHandlers.set("FusionOrderCancelledEvent", (event) => {
      console.log("❌ Fusion Order Cancelled:");
      console.log(`   Order: ${event.data.fusion_order}`);
      console.log(`   Owner: ${event.data.owner}`);
      console.log(`   Amount: ${event.data.source_amount}`);
    });

    this.eventHandlers.set("FusionOrderAcceptedEvent", (event) => {
      console.log("✅ Fusion Order Accepted:");
      console.log(`   Order: ${event.data.fusion_order}`);
      console.log(`   Resolver: ${event.data.resolver}`);
      console.log(`   Owner: ${event.data.owner}`);
      console.log(`   Amount: ${event.data.source_amount}`);
    });

    // Escrow Events
    this.eventHandlers.set("EscrowCreatedEvent", (event) => {
      console.log("🔒 Escrow Created:");
      console.log(`   Escrow: ${event.data.escrow}`);
      console.log(`   From: ${event.data.from}`);
      console.log(`   To: ${event.data.to}`);
      console.log(`   Resolver: ${event.data.resolver}`);
      console.log(`   Amount: ${event.data.amount}`);
      console.log(`   Chain ID: ${event.data.chain_id}`);
      console.log(`   Is Source Chain: ${event.data.is_source_chain}`);
    });

    this.eventHandlers.set("EscrowWithdrawnEvent", (event) => {
      console.log("🔓 Escrow Withdrawn:");
      console.log(`   Escrow: ${event.data.escrow}`);
      console.log(`   Recipient: ${event.data.recipient}`);
      console.log(`   Resolver: ${event.data.resolver}`);
      console.log(`   Amount: ${event.data.amount}`);
    });

    this.eventHandlers.set("EscrowRecoveredEvent", (event) => {
      console.log("💰 Escrow Recovered:");
      console.log(`   Escrow: ${event.data.escrow}`);
      console.log(`   Recovered By: ${event.data.recovered_by}`);
      console.log(`   Returned To: ${event.data.returned_to}`);
      console.log(`   Amount: ${event.data.amount}`);
    });

    // Hashlock Events
    this.eventHandlers.set("HashlockCreatedEvent", (event) => {
      console.log("🔐 Hashlock Created:");
      console.log(`   Hashlock: ${event.data.hashlock}`);
      console.log(`   Beneficiary: ${event.data.beneficiary}`);
      console.log(`   Amount: ${event.data.amount}`);
      console.log(`   Hash: ${event.data.hash}`);
      console.log(`   Timeout: ${event.data.timeout}`);
    });

    this.eventHandlers.set("HashlockReleasedEvent", (event) => {
      console.log("🔓 Hashlock Released:");
      console.log(`   Hashlock: ${event.data.hashlock}`);
      console.log(`   Released By: ${event.data.released_by}`);
      console.log(`   Amount: ${event.data.amount}`);
    });

    // Timelock Events
    this.eventHandlers.set("TimelockCreatedEvent", (event) => {
      console.log("⏰ Timelock Created:");
      console.log(`   Timelock: ${event.data.timelock}`);
      console.log(`   Beneficiary: ${event.data.beneficiary}`);
      console.log(`   Amount: ${event.data.amount}`);
      console.log(`   Unlock Time: ${event.data.unlock_time}`);
    });

    this.eventHandlers.set("TimelockExpiredEvent", (event) => {
      console.log("⏰ Timelock Expired:");
      console.log(`   Timelock: ${event.data.timelock}`);
      console.log(`   Expired By: ${event.data.expired_by}`);
      console.log(`   Amount: ${event.data.amount}`);
    });

    // Resolver Registry Events
    this.eventHandlers.set("ResolverRegisteredEvent", (event) => {
      console.log("📝 Resolver Registered:");
      console.log(`   Address: ${event.data.address}`);
      console.log(`   Name: ${event.data.name}`);
      console.log(`   URL: ${event.data.url}`);
    });

    this.eventHandlers.set("ResolverUnregisteredEvent", (event) => {
      console.log("🗑️ Resolver Unregistered:");
      console.log(`   Address: ${event.data.address}`);
    });

    this.eventHandlers.set("ResolverStatusChangedEvent", (event) => {
      console.log("🔄 Resolver Status Changed:");
      console.log(`   Address: ${event.data.address}`);
      console.log(`   Status: ${event.data.status}`);
    });
  }

  /**
   * Poll for events from the contract using REST API
   */
  private async pollEvents() {
    while (this.isListening) {
      try {
        // Get events from the contract using the actual event handles
        const eventHandles = [
          `${this.contractAddress}::fusion_order::FusionOrderEvents`,
          `${this.contractAddress}::escrow::EscrowEvents`,
          `${this.contractAddress}::hashlock::HashlockEvents`,
          `${this.contractAddress}::timelock::TimelockEvents`,
          `${this.contractAddress}::resolver_registry::ResolverRegistryEvents`,
        ];

        for (const eventHandle of eventHandles) {
          try {
            await this.pollEventsFromHandle(eventHandle);
          } catch (error) {
            // Event handle might not exist yet, ignore
            console.debug(`Event handle ${eventHandle} not found or no events`);
          }
        }

        // Wait before next poll
        await new Promise(resolve => setTimeout(resolve, 5000)); // Poll every 5 seconds
      } catch (error) {
        console.error("Error polling events:", error);
        await new Promise(resolve => setTimeout(resolve, 10000)); // Wait longer on error
      }
    }
  }

  /**
   * Poll events from a specific event handle using REST API
   */
  private async pollEventsFromHandle(eventHandle: string) {
    try {
      const lastSeq = this.lastSequenceNumbers.get(eventHandle) || 0;
      
      // Use REST API to get events
      const response = await fetch(`${this.aptos.config.fullnode}/accounts/${this.contractAddress}/events/${eventHandle}?start=${lastSeq}&limit=10`);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const events = await response.json();
      
      for (const event of events) {
        if (event.sequence_number > lastSeq) {
          await this.handleEvent(event);
          this.lastSequenceNumbers.set(eventHandle, event.sequence_number);
        }
      }
    } catch (error) {
      console.debug(`Error polling events from ${eventHandle}:`, (error as Error).message);
    }
  }

  /**
   * Handle a single event
   */
  private async handleEvent(event: Event) {
    console.log(`📡 Received event: ${event.type}`);
    console.log(`   Sequence: ${event.sequence_number}`);
    console.log(`   Data: ${JSON.stringify(event.data, null, 2)}`);

    // Extract event type from the full type string
    const eventType = event.type.split("::").pop();
    
    if (eventType && this.eventHandlers.has(eventType)) {
      const handler = this.eventHandlers.get(eventType);
      if (handler) {
        try {
          handler(event);
        } catch (error) {
          console.error(`Error handling event ${eventType}:`, error);
        }
      }
    } else {
      console.log(`📡 Unhandled event type: ${eventType}`);
    }
  }

  /**
   * Add a custom event handler
   */
  addEventHandler(eventType: string, handler: (event: Event) => void) {
    this.eventHandlers.set(eventType, handler);
    console.log(`📝 Added handler for event type: ${eventType}`);
  }

  /**
   * Remove an event handler
   */
  removeEventHandler(eventType: string) {
    this.eventHandlers.delete(eventType);
    console.log(`🗑️ Removed handler for event type: ${eventType}`);
  }

  /**
   * Get all registered event handlers
   */
  getEventHandlers(): string[] {
    return Array.from(this.eventHandlers.keys());
  }

  /**
   * Get contract events for a specific event handle
   */
  async getContractEvents(eventHandle: string, start: number = 0, limit: number = 10) {
    try {
      const response = await fetch(`${this.aptos.config.fullnode}/accounts/${this.contractAddress}/events/${eventHandle}?start=${start}&limit=${limit}`);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error(`Error getting events from ${eventHandle}:`, error);
      throw error;
    }
  }
} 