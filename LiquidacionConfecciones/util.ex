defmodule Util do
  @moduledoc """
  Funciones de apoyo puras: conversión del lote adicional escrito por el
  usuario y formato de números para los reportes.
  """
  @separador ";"
  @cantidad_campos 5

  @doc """
  Convierte el texto `confeccionista;linea;dia;prendas;defectos` en un lote.
  Solo revisa el formato. Las cinco reglas de negocio las aplica `Validacion`.
  """
  #parsear_lote/1 recibe un texto y lo convierte en un mapa que representa un lote, o devuelve un error si el formato es inválido
  #is_binary(texto) verifica si el valor de texto es una cadena de caracteres
  #string.split(texto, @separador) divide el texto en una lista de campos utilizando el separador ";"
  #Enum.map(&String.trim/1) recorre la lista de campos y elimina los espacios en blanco al inicio y al final de cada campo
  #with true <- length(campos) == @cantidad_campos, verifica si la cantidad de campos es igual a 5
  #[confeccionista, linea, dia, prendas, defectos] <- campos, asigna los valores de los campos a las variables correspondientes
  #parsear_entero(dia), parsear_entero(prendas) y parsear_numero(defectos)
  #convierten los valores de dia, prendas y defectos a enteros o números, devolviendo {:ok, valor} si tienen éxito
  def parsear_lote(texto) when is_binary(texto) do
    campos = texto |> String.split(@separador) |> Enum.map(&String.trim/1)

    with true <- length(campos) == @cantidad_campos,
         [confeccionista, linea, dia, prendas, defectos] <- campos,
         {:ok, dia} <- parsear_entero(dia),
         {:ok, prendas} <- parsear_entero(prendas),
         {:ok, defectos} <- parsear_numero(defectos) do
      {:ok,
       %{
         confeccionista: confeccionista,
         linea: linea,
         dia: dia,
         prendas: prendas,
         defectos: defectos
       }}
    else
      _ -> {:error, :formato_invalido}
    end
  end
  def parsear_lote(_otro), do: {:error, :formato_invalido}

  @doc """
  Convierte un texto en entero. Rechaza textos con letras o decimales
  (por ejemplo "12abc" o "3.5").
  """
  #integer.parse() convierte un texto en un número entero, devolviendo una tupla {entero, resto} si tiene éxito,
  #o :error si falla. En este caso, se espera que el resto sea una cadena vacía,
  #lo que indica que todo el texto se convirtió correctamente en un número entero.
  def parsear_entero(texto) do
    case Integer.parse(texto) do
      {entero, ""} -> {:ok, entero}
      _ -> {:error, :no_es_entero}
    end
  end

  @doc """
  Convierte un texto en número (entero o decimal con punto).
  Acepta "7" y "3.5"; rechaza "abc", "" y "3,5".
  """
  #float.parse() convierte un texto en un número de punto flotante, devolviendo una tupla {numero, resto} si tiene éxito,
  #o :error si falla. En este caso, se espera que el resto sea una
  #cadena vacía, lo que indica que todo el texto se convirtió correctamente en un número.
  def parsear_numero(texto) do
    case Float.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, :no_es_numero}
    end
  end

  @doc """
  Da formato a un número con exactamente dos decimales y sin notación científica.
  ## Ejemplos
      iex> Util.formatear_dinero(598560)
      "598560.00"
  """
  #erlang.float_to_binary() convierte un número en una cadena de texto con el formato especificado,
  #en este caso con dos decimales
  def formatear_dinero(numero) when is_number(numero) do
    :erlang.float_to_binary(numero * 1.0, decimals: 2)
  end
end
