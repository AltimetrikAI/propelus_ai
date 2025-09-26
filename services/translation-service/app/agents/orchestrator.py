"""
Main Orchestrator - Coordinates all agents in the translation pipeline
"""

from typing import Dict, Any, Optional
from langgraph.graph import Graph, END
from enum import Enum
import asyncio
import time

from .preprocessor import PreprocessorAgent
from .rule_matcher import RuleMatcherAgent
from .semantic_search import SemanticSearchAgent
from .llm_translator import LLMTranslationAgent
from .confidence_scorer import ConfidenceScorerAgent
from .validator import ValidatorAgent

class TranslationMethod(str, Enum):
    EXACT_MATCH = "exact_match"
    RULE_BASED = "rule_based"
    FUZZY_MATCH = "fuzzy_match"
    SEMANTIC_SEARCH = "semantic_search"
    LLM_TRANSLATION = "llm_translation"

class TranslationOrchestrator:
    """Main orchestrator for the translation pipeline"""
    
    def __init__(self, config: Dict[str, Any] = None):
        """
        Initialize the orchestrator with all agents
        
        Args:
            config: Configuration dictionary
        """
        self.config = config or {}
        
        # Initialize agents
        self.preprocessor = PreprocessorAgent()
        self.rule_matcher = RuleMatcherAgent()
        self.semantic_search = SemanticSearchAgent(
            index_path=self.config.get("faiss_index_path"),
            redis_host=self.config.get("redis_host", "localhost")
        )
        self.llm_translator = LLMTranslationAgent(
            model_id=self.config.get("llm_model_id", "anthropic.claude-3-sonnet-20240229-v1:0")
        )
        self.confidence_scorer = ConfidenceScorerAgent()
        self.validator = ValidatorAgent()
        
        # Build workflow graph
        self.workflow = self._build_workflow()
        
    def _build_workflow(self) -> Graph:
        """Build the agent workflow graph"""
        workflow = Graph()
        
        # Add nodes
        workflow.add_node("preprocess", self.preprocess_step)
        workflow.add_node("rule_match", self.rule_match_step)
        workflow.add_node("semantic_search", self.semantic_search_step)
        workflow.add_node("llm_translate", self.llm_translate_step)
        workflow.add_node("score_confidence", self.score_confidence_step)
        workflow.add_node("validate", self.validate_step)
        
        # Define workflow edges
        workflow.set_entry_point("preprocess")
        workflow.add_edge("preprocess", "rule_match")
        
        # Conditional routing from rule_match
        workflow.add_conditional_edges(
            "rule_match",
            self.should_continue_after_rules,
            {
                "semantic": "semantic_search",
                "confidence": "score_confidence"
            }
        )
        
        workflow.add_edge("semantic_search", "llm_translate")
        workflow.add_edge("llm_translate", "score_confidence")
        workflow.add_edge("score_confidence", "validate")
        workflow.add_edge("validate", END)
        
        return workflow.compile()
    
    async def preprocess_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """Preprocessing step"""
        result = await self.preprocessor.process(
            state["input_text"],
            state.get("context")
        )
        state["preprocessed"] = result
        return state
    
    async def rule_match_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """Rule-based matching step"""
        result = await self.rule_matcher.match(
            state["preprocessed"]["normalized"]
        )
        state["rule_match_result"] = result
        
        # If high confidence exact match, we can skip other steps
        if result and result.get("confidence", 0) >= 0.95:
            state["final_match"] = result
            state["method"] = TranslationMethod.EXACT_MATCH
        
        return state
    
    async def semantic_search_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """Semantic search step"""
        candidates = await self.semantic_search.search(
            state["preprocessed"]["normalized"],
            k=10,
            threshold=0.6
        )
        state["semantic_candidates"] = candidates
        
        # If very high semantic similarity, might skip LLM
        if candidates and candidates[0].get("similarity_score", 0) >= 0.92:
            state["final_match"] = candidates[0]
            state["method"] = TranslationMethod.SEMANTIC_SEARCH
        
        return state
    
    async def llm_translate_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """LLM translation step"""
        result = await self.llm_translator.translate(
            state["preprocessed"]["normalized"],
            state.get("semantic_candidates", []),
            state.get("context")
        )
        state["llm_result"] = result
        
        if result.get("primary_match"):
            state["final_match"] = result["primary_match"]
            state["alternatives"] = result.get("alternative_matches", [])
            state["method"] = TranslationMethod.LLM_TRANSLATION
        
        return state
    
    async def score_confidence_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """Confidence scoring step"""
        final_confidence = await self.confidence_scorer.calculate(
            method=state.get("method"),
            primary_match=state.get("final_match"),
            alternatives=state.get("alternatives", []),
            metadata={
                "rule_match": state.get("rule_match_result"),
                "semantic_scores": state.get("semantic_candidates", [])
            }
        )
        
        if state.get("final_match"):
            state["final_match"]["confidence"] = final_confidence
        
        return state
    
    async def validate_step(self, state: Dict[str, Any]) -> Dict[str, Any]:
        """Validation step"""
        is_valid = await self.validator.validate(
            state.get("final_match"),
            state.get("context")
        )
        
        state["is_valid"] = is_valid
        
        # Mark for human review if confidence is low
        if state.get("final_match", {}).get("confidence", 0) < 0.7:
            state["needs_review"] = True
        
        return state
    
    def should_continue_after_rules(self, state: Dict[str, Any]) -> str:
        """Determine next step after rule matching"""
        if state.get("final_match") and state.get("method") == TranslationMethod.EXACT_MATCH:
            return "confidence"
        return "semantic"
    
    async def translate(self, 
                        input_text: str,
                        context: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Main translation method
        
        Args:
            input_text: Raw profession text to translate
            context: Additional context (state, specialty, etc.)
            
        Returns:
            Translation result with confidence and metadata
        """
        start_time = time.time()
        
        # Initialize state
        state = {
            "input_text": input_text,
            "context": context or {},
            "timestamp": start_time
        }
        
        # Run workflow
        try:
            result = await self.workflow.ainvoke(state)
            
            # Calculate processing time
            processing_time = int((time.time() - start_time) * 1000)
            
            # Format response
            response = {
                "input_text": input_text,
                "translation": result.get("final_match"),
                "alternatives": result.get("alternatives", []),
                "method": result.get("method", "unknown"),
                "confidence": result.get("final_match", {}).get("confidence", 0),
                "needs_review": result.get("needs_review", False),
                "is_valid": result.get("is_valid", True),
                "processing_time_ms": processing_time,
                "metadata": {
                    "preprocessed": result.get("preprocessed", {}).get("normalized"),
                    "model_version": self.config.get("model_version", "1.0.0")
                }
            }
            
            return response
            
        except Exception as e:
            return {
                "input_text": input_text,
                "translation": None,
                "error": str(e),
                "processing_time_ms": int((time.time() - start_time) * 1000)
            }