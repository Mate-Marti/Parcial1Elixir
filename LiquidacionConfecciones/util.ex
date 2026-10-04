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
  
  def formatear_dinero(numero) when is_number(numero) do
    :erlang.float_to_binary(numero * 1.0, decimals: 2)
  end
end
