from bson import ObjectId
from passlib.context import CryptContext
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi
from config import DB_URI


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class DBConnection:
    def __init__(self):
        self.client = MongoClient(DB_URI, server_api=ServerApi('1'))
        self.db = self.client["ssi-system"]

        # Optional: test connection
        try:
            self.client.admin.command('ping')
            print("[MongoDB] Connected successfully.")
        except Exception as e:
            print("[MongoDB] Connection failed:", e)
            
    def get_db(self):
        return self.db


class UserStore:
    def __init__(self, db):
        self.collection = db["users"]

    def get_user_by_username(self, username):
        return self.collection.find_one({"username": username})

    def create_user(self, user_data):
        return self.collection.insert_one(user_data).inserted_id

    def update_user(self, username, update_fields):
        return self.collection.update_one({"username": username}, {"$set": update_fields})

    def delete_user(self, username):
        return self.collection.delete_one({"username": username})


class RequestStore:
    def __init__(self, db):
        self.collection = db["agent-requests"]
            
    def get_all_requests(self):
        results = self.collection.find({})
        return [self._serialize(doc) for doc in results]
    
    def _serialize(self, doc):
        doc = dict(doc)
        if "_id" in doc and isinstance(doc["_id"], ObjectId):
            doc["_id"] = str(doc["_id"])
        return doc
            
    def get_request_by_username(self, username):
        return self.collection.find_one({"username": username})
    
    def create_request(self, request_data):
        return self.collection.insert_one(request_data).inserted_id
    
    def update_request(self, username, update_fields):
        return self.collection.update_one({"username": username}, {"$set": update_fields})
    
    def delete_request(self, username):
        return self.collection.delete_one({"username": username})    


db_conn = DBConnection()
db = db_conn.get_db()

user_store = UserStore(db)
request_store = RequestStore(db)


def reset_db():
    collection = db["users"]
    collection.update_many({"role": { "$nin": ["admin"] }}, {"$set": {"role": ""}})
    
    collection = db["agent-requests"]
    collection.update_many({}, {"$set": {"status": "pending"}})
    
    print("[MongoDB] Collections reset.")
    
def get_users_db():
    """Return the user store"""
    return user_store

def get_requests_db():
    """Return the request store"""
    return request_store
