const { MongoClient, ObjectId: MongoObjectId } = require("mongodb");

// Helper for shell-like ObjectId (allows calling without 'new')
const ObjectId = (id) => new MongoObjectId(id);

// Helper for shell-like ISODate
const ISODate = (d) => (d ? new Date(d) : new Date());

/**
 * Enhanced Node.js executor for MongoDB queries.
 * This script is called by the mongo.nvim Lua plugin.
 */
async function run() {
  // Check argv length instead of falsy values to allow empty strings
  if (process.argv.length < 5) {
    const missing = [];
    if (process.argv.length < 3) missing.push("uri");
    if (process.argv.length < 4) missing.push("dbName");
    if (process.argv.length < 5) missing.push("query");
    console.error(`Missing required arguments: ${missing.join(", ")}`);
    process.exit(1);
  }

  const uri = process.argv[2];
  const dbName = process.argv[3] || "test"; // Default to test like mongosh
  const query = process.argv[4];

  const client = new MongoClient(uri);

  try {
    await client.connect();
    const baseDb = client.db(dbName);

    // Add shell-like compatibility helpers to the db object
    baseDb.getMongo = () => ({
      getDBNames: async () => {
        const adminDb = client.db("admin");
        const result = await adminDb.command({ listDatabases: 1 });
        return result.databases.map((d) => d.name);
      },
    });

    baseDb.getCollectionNames = async () => {
      const collections = await baseDb.listCollections().toArray();
      return collections.map((c) => c.name);
    };

    // Wrap db in a Proxy to support db.collectionName or db['collectionName']
    const db = new Proxy(baseDb, {
      get(target, prop) {
        // If it's an existing property or method, return it
        if (prop in target || typeof prop === "symbol") {
          return target[prop];
        }
        // Otherwise, treat it as a collection name
        return target.collection(prop);
      },
    });

    const execute = async () => {
      const wrappedQuery = query.includes("return") ? query : `return ${query}`;
      // Provide helpers to the function sandbox
      const fn = new Function(
        "db",
        "ObjectId",
        "ISODate",
        `return (async () => { 
                ${wrappedQuery} 
            })()`,
      );
      return await fn(db, ObjectId, ISODate);
    };

    const result = await execute();

    /**
     * Custom stringifier to preserve ObjectId and ISODate keywords.
     */
    const customStringify = (obj, indent = 2, level = 0) => {
      const spacing = " ".repeat(level * indent);
      const nextSpacing = " ".repeat((level + 1) * indent);

      if (obj === null) return "null";
      if (obj === undefined) return "undefined";

      // Check for ObjectId
      if (
        obj._bsontype === "ObjectId" ||
        (obj.constructor && obj.constructor.name === "ObjectId")
      ) {
        return `ObjectId("${obj.toString()}")`;
      }

      // Check for Date
      if (obj instanceof Date) {
        return `ISODate("${obj.toISOString()}")`;
      }

      if (Array.isArray(obj)) {
        if (obj.length === 0) return "[]";
        const items = obj.map((item) =>
          customStringify(item, indent, level + 1),
        );
        return `[\n${nextSpacing}${items.join(",\n" + nextSpacing)}\n${spacing}]`;
      }

      if (typeof obj === "object") {
        // Handle generic objects
        const keys = Object.keys(obj);
        if (keys.length === 0) return "{}";
        const pairs = keys.map((key) => {
          const value = customStringify(obj[key], indent, level + 1);
          return `"${key}": ${value}`;
        });
        return `{\n${nextSpacing}${pairs.join(",\n" + nextSpacing)}\n${spacing}}`;
      }

      if (typeof obj === "string") {
        return `"${obj}"`;
      }

      return String(obj);
    };

    // Output as formatted result using custom stringifier
    console.log(customStringify(result));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  } finally {
    await client.close();
  }
}

run();
