defmodule Util do
  # Muestra un mensaje simple con JOptionPane.showMessageDialog
  def mostrar_mensaje(mensaje) do
    System.cmd("java", ["-cp", ".", "Mensaje", "mostrar", mensaje])
  end

  # Muestra un mensaje de error con ícono de error
  def mostrar_error(mensaje) do
    System.cmd("java", ["-cp", ".", "Mensaje", "error", mensaje])
  end

  # pattern matching
  # Caso base: pide texto con JOptionPane.showInputDialog y limpia la respuesta.
  def ingresar(mensaje, :texto) do
    {resultado, _codigo_salida} = System.cmd("java", ["-cp", ".", "Mensaje", "input", mensaje])
    String.trim(resultado)
  end

  #el String.to_integer convierte un string a entero
  def ingresar(mensaje, :entero) do
    ingresar(mensaje, &String.to_integer/1, :entero)
  end

  #String.to_float convierte un string a float
  def ingresar(mensaje, :real) do
    ingresar(mensaje, &String.to_float/1, :real)
  end

  #el ArgumentError muestra que se espera
  def ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
      #parser.() es la forma de invocar una función anónima que está guardada en una variable llamada parser.
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar_error()

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  #el earlang.float_to_binary convierte un float a string con 2 decimales
  def formater(valor) do
    :erlang.float_to_binary(valor, decimals: 2)
  end

  #el String.downcase/1 convierte todos los caracteres de un string a minúsculas
  #El Enum.member? sirve para verificar si un elemento existe dentro de una colección (lista, mapa, rango, etc.). Devuelve true o false
  def ingresar(mensaje, :boolean) do
    valor =mensaje
  |> ingresar(:texto)
  |> String.downcase()
  |> Enum.member?(["si", "sí", "s"], valor)
  end
end
