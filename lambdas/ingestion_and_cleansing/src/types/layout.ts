/**
 * Layout Type Definitions (v1.0)
 * Represents the structure of taxonomy data with explicit node levels
 */

/**
 * Node level mapping (explicit level number to node type name)
 * Example: { level: 0, name: "Industry" }
 */
export interface NodeLevel {
  level: number;
  name: string;
}

/**
 * Master Taxonomy Layout (v1.0)
 * Required fields:
 * - Nodes: ordered list of node-type names
 * - Attributes: list of attribute-type names (includes ProfessionColumn)
 * - ProfessionColumn: name of column carrying profession string
 * - NodeLevels: explicit level-to-name mapping
 *
 * Example: {
 *   Nodes: ["Industry", "Major Group", "Profession"],
 *   Attributes: ["Taxonomy Code", "Notes", "Profession Name"],
 *   ProfessionColumn: "Profession Name",
 *   NodeLevels: [
 *     { level: 0, name: "Industry" },
 *     { level: 1, name: "Major Group" },
 *     { level: 5, name: "Profession" }
 *   ]
 * }
 */
export interface LayoutMaster {
  Nodes: string[];
  Attributes: string[];
  ProfessionColumn: string;
  NodeLevels: NodeLevel[];
}

/**
 * Customer Taxonomy Layout
 * Example: { "Proffesion column": { Profession: "Job Title" } }
 */
export interface LayoutCustomer {
  "Proffesion column": {
    Profession: string;
  };
}

/**
 * Union type for all layouts
 */
export type Layout = LayoutMaster | LayoutCustomer;
