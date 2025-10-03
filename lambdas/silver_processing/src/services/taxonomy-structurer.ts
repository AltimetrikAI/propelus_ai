/**
 * Taxonomy Structurer
 *
 * Structures extracted data into hierarchical taxonomy nodes.
 * Creates Industry → Group → Occupation → Specialty → Profession hierarchy.
 */

import { AppDataSource } from '../../../../shared/database/connection';
import { logger } from '../../../../shared/utils/logger';
import {
  SilverTaxonomies,
  SilverTaxonomiesNodes,
  SilverTaxonomiesNodesTypes,
  SilverTaxonomiesNodesAttributes,
} from '../../../../shared/database/entities/silver.entity';
import { ProfessionInfo } from './nlp-service';

export class TaxonomyStructurer {
  private nodeTypeCache: Map<string, SilverTaxonomiesNodesTypes> = new Map();

  constructor() {
    this.initializeNodeTypes();
  }

  /**
   * Initialize node types cache
   */
  private async initializeNodeTypes(): Promise<void> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodesTypes);
    const nodeTypes = await repo.find();

    for (const nodeType of nodeTypes) {
      this.nodeTypeCache.set(nodeType.name.toLowerCase(), nodeType);
    }

    logger.info(`Loaded ${nodeTypes.length} node types into cache`);
  }

  /**
   * Structure data into taxonomy nodes
   */
  async structureData(
    data: Record<string, any>,
    taxonomy: SilverTaxonomies,
    professionInfo: ProfessionInfo
  ): Promise<SilverTaxonomiesNodes[]> {
    logger.info('Structuring taxonomy data', { taxonomyId: taxonomy.taxonomy_id });

    const nodes: SilverTaxonomiesNodes[] = [];

    try {
      // Ensure node types exist
      await this.ensureNodeTypesExist();

      // Build hierarchy: Industry → Group → Occupation → Specialty → Profession
      let currentParent: SilverTaxonomiesNodes | null = null;

      // Level 1: Industry (e.g., "Healthcare")
      const industry = data.industry || 'Healthcare';
      const industryNode = await this.createOrGetNode(
        taxonomy.taxonomy_id,
        'Industry',
        industry,
        null,
        1,
        professionInfo.name
      );
      nodes.push(industryNode);
      currentParent = industryNode;

      // Level 2: Group (e.g., "Medical Professionals")
      const group = data.group || this.inferGroup(professionInfo.name);
      const groupNode = await this.createOrGetNode(
        taxonomy.taxonomy_id,
        'Group',
        group,
        currentParent.node_id,
        2,
        professionInfo.name
      );
      nodes.push(groupNode);
      currentParent = groupNode;

      // Level 3: Occupation (e.g., "Nursing")
      const occupation = data.occupation || this.inferOccupation(professionInfo.name);
      const occupationNode = await this.createOrGetNode(
        taxonomy.taxonomy_id,
        'Occupation',
        occupation,
        currentParent.node_id,
        3,
        professionInfo.name
      );
      nodes.push(occupationNode);
      currentParent = occupationNode;

      // Level 4: Specialty (if applicable, e.g., "Registered Nurse")
      if (data.specialty || this.hasSpecialty(professionInfo.name)) {
        const specialty = data.specialty || professionInfo.name;
        const specialtyNode = await this.createOrGetNode(
          taxonomy.taxonomy_id,
          'Specialty',
          specialty,
          currentParent.node_id,
          4,
          professionInfo.name
        );
        nodes.push(specialtyNode);
        currentParent = specialtyNode;
      }

      // Level 5: Profession (leaf node, e.g., "RN - California")
      const professionValue = this.buildProfessionValue(professionInfo, data);
      const professionNode = await this.createOrGetNode(
        taxonomy.taxonomy_id,
        'Profession',
        professionValue,
        currentParent.node_id,
        5,
        professionInfo.name
      );
      nodes.push(professionNode);

      // Add attributes to profession node
      await this.addNodeAttributes(professionNode.node_id, professionInfo.attributes, data);

      logger.info('Taxonomy structure created', {
        taxonomyId: taxonomy.taxonomy_id,
        nodesCreated: nodes.length,
      });

      return nodes;
    } catch (error) {
      logger.error('Failed to structure taxonomy data', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  /**
   * Create or get existing node
   */
  private async createOrGetNode(
    taxonomyId: number,
    nodeTypeName: string,
    value: string,
    parentNodeId: number | null,
    level: number,
    profession: string
  ): Promise<SilverTaxonomiesNodes> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodes);

    // Get node type
    const nodeType = await this.getOrCreateNodeType(nodeTypeName, level);

    // Check if node exists
    const existing = await repo.findOne({
      where: {
        taxonomy_id: taxonomyId,
        node_type_id: nodeType.node_type_id,
        value,
        parent_node_id: parentNodeId || undefined,
      },
    });

    if (existing) {
      return existing;
    }

    // Create new node
    const node = repo.create({
      node_type_id: nodeType.node_type_id,
      taxonomy_id: taxonomyId,
      parent_node_id: parentNodeId || undefined,
      value,
      profession,
      level,
    });

    return await repo.save(node);
  }

  /**
   * Get or create node type
   */
  private async getOrCreateNodeType(
    name: string,
    level: number
  ): Promise<SilverTaxonomiesNodesTypes> {
    const cached = this.nodeTypeCache.get(name.toLowerCase());
    if (cached) return cached;

    const repo = AppDataSource.getRepository(SilverTaxonomiesNodesTypes);

    let nodeType = await repo.findOne({ where: { name } });

    if (!nodeType) {
      nodeType = repo.create({
        name,
        level,
        status: 'active',
      });
      await repo.save(nodeType);
      this.nodeTypeCache.set(name.toLowerCase(), nodeType);
      logger.info('Created new node type', { name, level });
    }

    return nodeType;
  }

  /**
   * Ensure basic node types exist
   */
  private async ensureNodeTypesExist(): Promise<void> {
    const requiredTypes = [
      { name: 'Industry', level: 1 },
      { name: 'Group', level: 2 },
      { name: 'Occupation', level: 3 },
      { name: 'Specialty', level: 4 },
      { name: 'Profession', level: 5 },
    ];

    for (const type of requiredTypes) {
      await this.getOrCreateNodeType(type.name, type.level);
    }
  }

  /**
   * Infer group from profession name
   */
  private inferGroup(professionName: string): string {
    const name = professionName.toLowerCase();

    if (name.includes('nurse') || name.includes('rn') || name.includes('lpn')) {
      return 'Nursing Professionals';
    }
    if (name.includes('doctor') || name.includes('physician') || name.includes('md')) {
      return 'Medical Doctors';
    }
    if (name.includes('therapist') || name.includes('therapy')) {
      return 'Allied Health Professionals';
    }
    if (name.includes('pharmacist') || name.includes('pharmacy')) {
      return 'Pharmacy Professionals';
    }
    if (name.includes('dentist') || name.includes('dental')) {
      return 'Dental Professionals';
    }

    return 'Healthcare Professionals';
  }

  /**
   * Infer occupation from profession name
   */
  private inferOccupation(professionName: string): string {
    const name = professionName.toLowerCase();

    if (name.includes('nurse')) return 'Nursing';
    if (name.includes('doctor') || name.includes('physician')) return 'Medicine';
    if (name.includes('therapist')) return 'Therapy';
    if (name.includes('pharmacist')) return 'Pharmacy';
    if (name.includes('dentist')) return 'Dentistry';

    return 'General Healthcare';
  }

  /**
   * Check if profession has specialty
   */
  private hasSpecialty(professionName: string): boolean {
    const name = professionName.toLowerCase();
    return (
      name.includes('registered') ||
      name.includes('licensed') ||
      name.includes('certified') ||
      name.includes('specialist')
    );
  }

  /**
   * Build profession value with state/context
   */
  private buildProfessionValue(
    professionInfo: ProfessionInfo,
    data: Record<string, any>
  ): string {
    let value = professionInfo.name;

    if (data.state || professionInfo.attributes.state_code) {
      value += ` - ${data.state || professionInfo.attributes.state_code}`;
    }

    if (data.issuing_authority) {
      value += ` (${data.issuing_authority})`;
    }

    return value;
  }

  /**
   * Add attributes to node
   */
  private async addNodeAttributes(
    nodeId: number,
    attributes: Record<string, any>,
    rawData: Record<string, any>
  ): Promise<void> {
    const repo = AppDataSource.getRepository(SilverTaxonomiesNodesAttributes);

    // Combine extracted attributes with raw data
    const allAttributes = { ...attributes, ...rawData };

    for (const [key, value] of Object.entries(allAttributes)) {
      if (value !== undefined && value !== null) {
        const attr = repo.create({
          node_id: nodeId,
          Attribute_type_id: 1, // Default attribute type
          name: key,
          value: typeof value === 'string' ? value : JSON.stringify(value),
        });
        await repo.save(attr);
      }
    }
  }
}
