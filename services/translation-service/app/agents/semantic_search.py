"""
Semantic Search Agent - Vector embedding based search
"""

import numpy as np
from typing import List, Dict, Any, Optional
import faiss
from langchain.embeddings import BedrockEmbeddings
import boto3
import redis
import json
import hashlib

class SemanticSearchAgent:
    """Agent for semantic similarity search using embeddings"""
    
    def __init__(self, 
                 index_path: str = None,
                 redis_host: str = "localhost",
                 redis_port: int = 6379):
        """
        Initialize semantic search agent
        
        Args:
            index_path: Path to FAISS index
            redis_host: Redis host for caching
            redis_port: Redis port
        """
        # Initialize Bedrock embeddings
        self.bedrock_client = boto3.client(
            service_name='bedrock-runtime',
            region_name='us-east-1'
        )
        
        self.embeddings = BedrockEmbeddings(
            client=self.bedrock_client,
            model_id="amazon.titan-embed-text-v1"
        )
        
        # Initialize FAISS index
        self.index = None
        self.profession_mappings = {}
        if index_path:
            self.load_index(index_path)
        
        # Initialize Redis cache
        self.cache = redis.Redis(
            host=redis_host,
            port=redis_port,
            decode_responses=True
        )
        
    def load_index(self, index_path: str):
        """Load FAISS index and profession mappings"""
        self.index = faiss.read_index(index_path)
        # Load profession mappings (id to profession data)
        with open(f"{index_path}.mappings.json", "r") as f:
            self.profession_mappings = json.load(f)
    
    def _get_cache_key(self, text: str) -> str:
        """Generate cache key for text"""
        return f"embedding:{hashlib.md5(text.encode()).hexdigest()}"
    
    async def get_embedding(self, text: str) -> np.ndarray:
        """
        Get embedding for text with caching
        
        Args:
            text: Input text
            
        Returns:
            Embedding vector
        """
        # Check cache
        cache_key = self._get_cache_key(text)
        cached = self.cache.get(cache_key)
        
        if cached:
            return np.frombuffer(cached, dtype=np.float32)
        
        # Generate embedding
        embedding = await self.embeddings.aembed_query(text)
        embedding_array = np.array(embedding, dtype=np.float32)
        
        # Cache embedding (TTL: 7 days)
        self.cache.setex(
            cache_key,
            604800,
            embedding_array.tobytes()
        )
        
        return embedding_array
    
    async def search(self, 
                     query: str,
                     k: int = 10,
                     threshold: float = 0.7) -> List[Dict[str, Any]]:
        """
        Search for similar professions
        
        Args:
            query: Normalized query text
            k: Number of results to return
            threshold: Minimum similarity threshold
            
        Returns:
            List of similar professions with scores
        """
        if not self.index:
            return []
        
        # Get query embedding
        query_embedding = await self.get_embedding(query)
        query_embedding = query_embedding.reshape(1, -1)
        
        # Search in FAISS
        distances, indices = self.index.search(query_embedding, k)
        
        # Convert to results
        results = []
        for i, (dist, idx) in enumerate(zip(distances[0], indices[0])):
            if idx == -1:  # No more results
                break
                
            # Convert L2 distance to cosine similarity
            similarity = 1 - (dist / 2)
            
            if similarity < threshold:
                continue
            
            profession_data = self.profession_mappings.get(str(idx), {})
            results.append({
                "profession_id": profession_data.get("id"),
                "profession_name": profession_data.get("name"),
                "profession_code": profession_data.get("code"),
                "similarity_score": float(similarity),
                "rank": i + 1
            })
        
        return results
    
    async def build_index(self, professions: List[Dict[str, Any]]):
        """
        Build FAISS index from profession data
        
        Args:
            professions: List of profession dictionaries
        """
        embeddings = []
        mappings = {}
        
        for i, prof in enumerate(professions):
            # Create text representation
            text = f"{prof['name']} {prof.get('display_name', '')} {prof.get('description', '')}"
            
            # Get embedding
            embedding = await self.get_embedding(text)
            embeddings.append(embedding)
            
            # Store mapping
            mappings[str(i)] = {
                "id": prof["id"],
                "name": prof["name"],
                "code": prof["code"]
            }
        
        # Create FAISS index
        embeddings_matrix = np.array(embeddings, dtype=np.float32)
        dimension = embeddings_matrix.shape[1]
        
        # Use Inner Product for cosine similarity
        self.index = faiss.IndexFlatIP(dimension)
        self.index.add(embeddings_matrix)
        
        self.profession_mappings = mappings