package exm.parser.util;

import exm.ast.Context;

public class InvalidSyntaxException extends UserException {

  /**
   * 
   */
  private static final long serialVersionUID = 1060914609057739598L;

  public InvalidSyntaxException(Context context, String message) {
    super(context, message);
  }

}
