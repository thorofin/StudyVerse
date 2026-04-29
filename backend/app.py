"""
StudyVerse — Developer 3 Backend
Flask + Ollama (Mistral) + RAG with LangChain
──────────────────────────────────────────────
Routes:
 POST /api/upload         - Upload & index PDF
 POST /api/add_url        - Extract & index URL
 POST /api/ask            - RAG Q&A
 POST /api/summarize      - Summarize resource
 POST /api/quiz           - Generate quiz
 POST /api/explain        - Explain topic
 GET  /api/health         - Health check
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import uuid
import logging
import traceback

# LangChain / vector store
from langchain_community.llms.ollama import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.document_loaders import PyPDFLoader, WebBaseLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma
from langchain.chains.retrieval_qa.base import RetrievalQA
from langchain.prompts import PromptTemplate
from flask import send_from_directory

# App setup
app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

UPLOAD_DIR = "uploads"
CHROMA_DIR = "chroma_db"
os.makedirs(UPLOAD_DIR, exist_ok=True)

OLLAMA_BASE = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
MODEL_NAME  = os.getenv("OLLAMA_MODEL", "mistral")

# Singletons
_llm        = None
_embeddings = None
_vectordb   = None   # shared Chroma instance
_splitter   = RecursiveCharacterTextSplitter(chunk_size=800, chunk_overlap=100)

def get_llm():
    global _llm
    if _llm is None:
        _llm = Ollama(model=MODEL_NAME, base_url=OLLAMA_BASE, temperature=0.3)
    return _llm

def get_embeddings():
    global _embeddings
    if _embeddings is None:
        _embeddings = OllamaEmbeddings(model=MODEL_NAME, base_url=OLLAMA_BASE)
    return _embeddings

def get_vectordb():
    global _vectordb
    if _vectordb is None:
        _vectordb = Chroma(
            persist_directory=CHROMA_DIR,
            embedding_function=get_embeddings(),
        )
    return _vectordb

# RAG helper
def _build_retriever(resource_ids: list[str] | None):
    db = get_vectordb()
    kwargs = {"k": 5}
    if resource_ids:
        kwargs["filter"] = None
    return db.as_retriever(search_kwargs=kwargs)

def _rag_answer(question: str, resource_ids: list[str] | None = None) -> str:
    retriever = _build_retriever(resource_ids)

    prompt = PromptTemplate(
        template=(
            "You are a helpful academic assistant in StudyVerse.\n"
            "Use the following context to answer the question.\n\n"
            "Context:\n{context}\n\n"
            "Question: {question}\n"
            "Answer:"
        ),
        input_variables=["context", "question"],
    )

    chain = RetrievalQA.from_chain_type(
        llm=get_llm(),
        chain_type="stuff",
        retriever=retriever,
        chain_type_kwargs={"prompt": prompt},
        return_source_documents=False
    )

    result = chain.invoke({"query": question})

    # FIX: handle multiple LangChain response formats safely
    if isinstance(result, dict):
        return result.get("result") or result.get("answer") or str(result)

    return str(result)

# Routes

@app.route("/api/health", methods=["GET"])
def health():
    try:
        get_llm()   # lazy-load to test connection
        return jsonify({"status": "ok", "model": MODEL_NAME})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 503


@app.route("/api/upload", methods=["POST"])
def upload_pdf():
    """Receive PDF, chunk it, embed into Chroma with resource_id metadata."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    resource_id = request.form.get("resource_id", str(uuid.uuid4()))
    file = request.files["file"]
    save_path = os.path.join(UPLOAD_DIR, f"{resource_id}.pdf")
    file.save(save_path)

    try:
        loader = PyPDFLoader(save_path)
        pages  = loader.load()
        chunks = _splitter.split_documents(pages)

        # Attach resource_id to every chunk for filtered retrieval
        for chunk in chunks:
            chunk.metadata["resource_id"] = resource_id

        db = get_vectordb()
        db.add_documents(chunks)
        db.persist()

        extracted = " ".join(p.page_content for p in pages[:2])[:500]  # preview
        logger.info(f"Indexed {len(chunks)} chunks for resource {resource_id}")
        return jsonify({
            "resource_id": resource_id,
            "chunks": len(chunks),
            "extracted_text": extracted,
        })
    except Exception:
        logger.error(traceback.format_exc())
        return jsonify({"error": "PDF processing failed"}), 500


@app.route("/api/add_url", methods=["POST"])
def add_url():
    """Fetch URL, chunk content, embed into Chroma."""
    data = request.get_json(silent=True) or {}
    url  = data.get("url", "")
    resource_id = data.get("resource_id", str(uuid.uuid4()))

    if not url:
        return jsonify({"error": "No URL provided"}), 400

    try:
        loader = WebBaseLoader(url)
        docs   = loader.load()
        chunks = _splitter.split_documents(docs)

        for chunk in chunks:
            chunk.metadata["resource_id"] = resource_id

        db = get_vectordb()
        db.add_documents(chunks)
        db.persist()

        extracted = " ".join(d.page_content for d in docs[:1])[:500]
        logger.info(f"Indexed {len(chunks)} chunks for URL resource {resource_id}")
        return jsonify({
            "resource_id": resource_id,
            "chunks": len(chunks),
            "extracted_text": extracted,
        })
    except Exception:
        logger.error(traceback.format_exc())
        return jsonify({"error": "URL extraction failed"}), 500


@app.route("/api/ask", methods=["POST"])
def ask():
    """RAG-powered question answering."""
    data         = request.get_json(silent=True) or {}
    question     = data.get("question", "").strip()
    resource_ids = data.get("resource_ids", [])

    if not question:
        return jsonify({"error": "No question provided"}), 400

    try:
        answer = _rag_answer(question, resource_ids or None)
        return jsonify({"answer": answer})
    except Exception:
        logger.error(traceback.format_exc())
        return jsonify({"error": "Failed to answer question"}), 500


@app.route("/api/summarize", methods=["POST"])
def summarize():
    """Generate a structured summary for a resource."""
    data        = request.get_json(silent=True) or {}
    resource_id = data.get("resource_id", "")

    if not resource_id:
        return jsonify({"error": "No resource_id provided"}), 400

    prompt = (
        "Provide a clear, structured academic summary of the document. "
        "Include: main topics, key points, important definitions, and conclusions. "
        "Use markdown formatting with headers."
    )
    try:
        summary = _rag_answer(prompt, [resource_id])
        return jsonify({"summary": summary})
    except Exception:
        logger.error(traceback.format_exc())
        return jsonify({"error": "Summarization failed"}), 500


@app.route("/api/quiz", methods=["POST"])
def quiz():
    """Generate multiple-choice quiz questions from a resource."""
    data           = request.get_json(silent=True) or {}
    resource_id    = data.get("resource_id", "")
    question_count = int(data.get("question_count", 5))

    if not resource_id:
        return jsonify({"error": "No resource_id provided"}), 400

    prompt = (
        f"Generate exactly {question_count} multiple-choice quiz questions based on "
        f"the document content. For each question provide:\n"
        f"- The question\n"
        f"- Four options (A, B, C, D)\n"
        f"- The correct answer\n"
        f"- A brief explanation\n\n"
        f"Use markdown formatting."
    )
    try:
        quiz_text = _rag_answer(prompt, [resource_id])
        return jsonify({"quiz": quiz_text})
    except Exception:
        logger.error(traceback.format_exc())
        return jsonify({"error": "Quiz generation failed"}), 500


@app.route("/api/explain", methods=["POST"])
def explain():
    """Explain a specific topic from a resource."""
    data        = request.get_json(silent=True) or {}
    resource_id = data.get("resource_id", "")
    topic       = data.get("topic", "the main concepts")

    prompt = (
        f"Explain '{topic}' clearly and thoroughly based on the document. "
        f"Use simple language, examples from the text, and analogies where helpful. "
        f"Format the explanation with markdown."
    )
    try:
        explanation = _rag_answer(prompt, [resource_id] if resource_id else None)
        return jsonify({"explanation": explanation})
    except Exception:
        logger.error(traceback.format_exc())
        return jsonify({"error": "Explanation failed"}), 500
@app.route('/uploads/<path:filename>')
def serve_file(filename):
    return send_from_directory('uploads', filename)

# Entry point
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)