"""
LLM Translation Agent - GenAI-powered profession matching
"""

from typing import List, Dict, Any, Optional
import json
from langchain.llms.bedrock import Bedrock
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
import boto3

class LLMTranslationAgent:
    """Agent for LLM-based profession translation"""
    
    def __init__(self, model_id: str = "anthropic.claude-3-sonnet-20240229-v1:0"):
        """
        Initialize LLM translation agent
        
        Args:
            model_id: Bedrock model ID
        """
        self.bedrock_client = boto3.client(
            service_name='bedrock-runtime',
            region_name='us-east-1'
        )
        
        self.llm = Bedrock(
            client=self.bedrock_client,
            model_id=model_id,
            model_kwargs={
                "temperature": 0.1,
                "max_tokens": 1000
            }
        )
        
        # Create translation prompt
        self.prompt_template = PromptTemplate(
            input_variables=["input_text", "context", "candidate_professions"],
            template="""You are a healthcare profession taxonomy expert. Your task is to map the given profession text to the most appropriate standardized profession from our taxonomy.

Input Profession: {input_text}
Additional Context: {context}

Available Standard Professions:
{candidate_professions}

Instructions:
1. Analyze the input profession text carefully
2. Consider common variations, abbreviations, and related terms
3. Match to the most specific appropriate profession
4. If multiple matches are possible, rank them by relevance
5. Provide confidence score between 0 and 1

Response Format (JSON):
{{
    "primary_match": {{
        "profession_id": "uuid",
        "profession_name": "name",
        "profession_code": "code",
        "confidence": 0.00,
        "reasoning": "explanation"
    }},
    "alternative_matches": [
        {{
            "profession_id": "uuid",
            "profession_name": "name",
            "profession_code": "code",
            "confidence": 0.00
        }}
    ]
}}

Examples:
- Input: "RN" → Output: {{"primary_match": {{"profession_name": "Registered Nurse", "confidence": 0.95}}}}
- Input: "Physical Therapy Assistant" → Output: {{"primary_match": {{"profession_name": "Physical Therapist Assistant", "confidence": 0.92}}}}
- Input: "Dental Hygiene" → Output: {{"primary_match": {{"profession_name": "Dental Hygienist", "confidence": 0.88}}}}

Now translate the input profession and return ONLY valid JSON:"""
        )
        
        self.chain = LLMChain(llm=self.llm, prompt=self.prompt_template)
    
    def _format_candidates(self, candidates: List[Dict[str, Any]]) -> str:
        """Format candidate professions for prompt"""
        formatted = []
        for i, candidate in enumerate(candidates[:10], 1):  # Limit to top 10
            formatted.append(
                f"{i}. {candidate['profession_name']} "
                f"(Code: {candidate['profession_code']}, "
                f"ID: {candidate['profession_id']})"
            )
        return "\n".join(formatted)
    
    async def translate(self,
                        input_text: str,
                        candidates: List[Dict[str, Any]],
                        context: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Translate profession using LLM
        
        Args:
            input_text: Normalized input text
            candidates: Candidate professions from semantic search
            context: Additional context
            
        Returns:
            Translation result with confidence scores
        """
        # Format candidates for prompt
        candidates_str = self._format_candidates(candidates)
        
        # Format context
        context_str = json.dumps(context) if context else "{}"
        
        try:
            # Run LLM chain
            response = await self.chain.arun(
                input_text=input_text,
                context=context_str,
                candidate_professions=candidates_str
            )
            
            # Parse JSON response
            result = json.loads(response)
            
            # Validate response structure
            if "primary_match" not in result:
                raise ValueError("Invalid LLM response format")
            
            return result
            
        except json.JSONDecodeError:
            # Fallback to best semantic match
            if candidates:
                return {
                    "primary_match": {
                        "profession_id": candidates[0]["profession_id"],
                        "profession_name": candidates[0]["profession_name"],
                        "profession_code": candidates[0]["profession_code"],
                        "confidence": candidates[0].get("similarity_score", 0.5) * 0.8,
                        "reasoning": "LLM parsing failed, using semantic similarity"
                    },
                    "alternative_matches": candidates[1:5]
                }
            else:
                return {
                    "primary_match": None,
                    "alternative_matches": [],
                    "error": "No matches found"
                }
        
        except Exception as e:
            return {
                "primary_match": None,
                "alternative_matches": candidates[:5] if candidates else [],
                "error": str(e)
            }