import { Db, Collection, ObjectId as MongoObjectId } from 'mongodb';

declare global {
    /**
     * ShellDb extends the standard Db type with an index signature 
     * to support db['collection'] or db.collection access.
     */
    interface ShellDb extends Db {
        [collectionName: string]: Collection<any>;
    }

    const db: ShellDb;

    /**
     * Helper for shell-like ObjectId (allows calling without 'new')
     */
    function ObjectId(id?: string | number | MongoObjectId): MongoObjectId;

    /**
     * Helper for shell-like ISODate
     */
    function ISODate(d?: string | number | Date): Date;
}

export { };
