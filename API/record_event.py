from get_db_connection import get_db_connection

def record_event(mcuMacAddress:str, event_type:str):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("exec record_event %s, %s", 
            (mcuMacAddress, event_type))
        conn.commit()
        return {"status": "success", "message": "Event recorded successfully"}
    except Exception as e:
        print(f"Error occurred: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        cursor.close()
        conn.close()
