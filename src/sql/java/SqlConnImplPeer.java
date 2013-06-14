//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jun 07  Brian Frank  Creation
//
package fan.sql;

import java.sql.*;
import java.util.StringTokenizer;
import fan.sys.*;

public class SqlConnImplPeer
{

//////////////////////////////////////////////////////////////////////////
// Peer Factory
//////////////////////////////////////////////////////////////////////////

  public static SqlConnImplPeer make(SqlConnImpl fan)
  {
    return new SqlConnImplPeer();
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  public static SqlConn openDefault(String uri, String user, String pass)
  {
    try
    {
      SqlConnImpl self = SqlConnImpl.make();
      self.peer.jconn = DriverManager.getConnection(uri, user, pass);
      self.peer.supportsGetGenKeys = self.peer.jconn.getMetaData().supportsGetGeneratedKeys();
      return self;
    }
    catch (SQLException e)
    {
      throw err(e);
    }
  }

  public static SqlConn wrapConnection(java.sql.Connection jconn)
  {
    try
    {
        SqlConnImpl self = SqlConnImpl.make();
        self.peer.jconn = jconn;
        self.peer.supportsGetGenKeys = self.peer.jconn.getMetaData().supportsGetGeneratedKeys();
        return self;
    }
    catch (SQLException e)
    {
        throw err(e);
    }
  }

  public boolean isClosed(SqlConnImpl self)
  {
    try
    {
      return jconn.isClosed();
    }
    catch (SQLException e)
    {
      throw err(e);
    }
  }

  public boolean close(SqlConnImpl self)
  {
    try
    {
      jconn.close();
      return true;
    }
    catch (Throwable e)
    {
      e.printStackTrace();
      return false;
    }
  }

//////////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////////

  public SqlMeta meta(SqlConnImpl self)
  {
    try
    {
      SqlMeta meta = new SqlMeta();
      meta.peer.jmeta = jconn.getMetaData();
      return meta;
    }
    catch (SQLException ex)
    {
      throw err(ex);
    }
  }

//////////////////////////////////////////////////////////////////////////
// Transactions
//////////////////////////////////////////////////////////////////////////

  public boolean autoCommit(SqlConnImpl self)
  {
    try
    {
      return jconn.getAutoCommit();
    }
    catch (SQLException e)
    {
      throw err(e);
    }
  }

  public void autoCommit(SqlConnImpl self, boolean b)
  {
    try
    {
      jconn.setAutoCommit(b);
    }
    catch (SQLException e)
    {
      throw err(e);
    }
  }

  public void commit(SqlConnImpl self)
  {
    try
    {
      jconn.commit();
    }
    catch (SQLException e)
    {
      throw err(e);
    }
  }

  public void rollback(SqlConnImpl self)
  {
    try
    {
      jconn.rollback();
    }
    catch (SQLException e)
    {
      throw err(e);
    }
  }

//////////////////////////////////////////////////////////////////////////
// Load Driver
//////////////////////////////////////////////////////////////////////////

  static { loadDrivers(); }

  static void loadDrivers()
  {
    try
    {
      String val = Pod.find("sql").config("java.drivers");
      if (val == null) return;
      String[] classNames = val.split(",");
      for (int i=0; i<classNames.length; ++i)
      {
        String className = classNames[i].trim();
        try
        {
          Class.forName(className);
        }
        catch (Exception e)
        {
          System.out.println("WARNING: Cannot preload JDBC driver: " + className);
        }
      }
    }
    catch (Throwable e)
    {
      System.out.println(e);
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static RuntimeException err(SQLException e)
  {
    return SqlErr.make(e.getMessage(), Err.make(e));
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  java.sql.Connection jconn;
  Map meta;
  boolean supportsGetGenKeys;
}