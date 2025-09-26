"""
Preprocessor Agent - Text normalization and cleaning
"""

import re
import string
from typing import Dict, Any
import spacy
from spellchecker import SpellChecker

class PreprocessorAgent:
    """Agent for preprocessing and normalizing input text"""
    
    def __init__(self):
        self.nlp = spacy.load("en_core_web_sm")
        self.spell = SpellChecker()
        
        # Common healthcare abbreviations
        self.abbreviations = {
            "rn": "registered nurse",
            "np": "nurse practitioner", 
            "md": "medical doctor",
            "do": "doctor of osteopathy",
            "pa": "physician assistant",
            "pt": "physical therapist",
            "ot": "occupational therapist",
            "dds": "doctor of dental surgery",
            "phd": "doctor of philosophy",
            "lpn": "licensed practical nurse",
            "cna": "certified nursing assistant",
            "emt": "emergency medical technician"
        }
    
    async def process(self, input_text: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Process and normalize input text
        
        Args:
            input_text: Raw profession text
            context: Additional context
            
        Returns:
            Processed text and metadata
        """
        # Store original
        original = input_text
        
        # Convert to lowercase
        text = input_text.lower().strip()
        
        # Remove extra whitespace
        text = ' '.join(text.split())
        
        # Expand abbreviations
        for abbr, expansion in self.abbreviations.items():
            text = re.sub(r'\b' + abbr + r'\b', expansion, text)
        
        # Remove special characters but keep spaces
        text = re.sub(r'[^\w\s]', ' ', text)
        text = ' '.join(text.split())
        
        # Spell correction for non-medical terms
        tokens = text.split()
        corrected_tokens = []
        for token in tokens:
            if token not in self.abbreviations and len(token) > 3:
                correction = self.spell.correction(token)
                corrected_tokens.append(correction if correction else token)
            else:
                corrected_tokens.append(token)
        
        normalized_text = ' '.join(corrected_tokens)
        
        # Extract entities using spaCy
        doc = self.nlp(normalized_text)
        entities = [(ent.text, ent.label_) for ent in doc.ents]
        
        return {
            "original": original,
            "normalized": normalized_text,
            "tokens": corrected_tokens,
            "entities": entities,
            "context": context or {}
        }