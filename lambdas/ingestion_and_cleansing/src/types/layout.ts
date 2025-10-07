/**
 * Layout Type Definitions
 * Represents the structure of taxonomy data
 */

/**
 * Master Taxonomy Layout
 * Example: { Nodes: ["Industry", "Group", "Occupation"], Attributes: ["Level", "Status"] }
 */
export interface LayoutMaster {
  Nodes: string[];
  Attributes: string[];
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
