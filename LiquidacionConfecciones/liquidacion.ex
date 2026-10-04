# Integrantes: (escriban aquí los nombres del grupo)

defmodule Liquidacion do
  @moduledoc """
  Liquidación de la producción semanal. Todas las funciones son puras.

  """
#se definen constantes para los rangos de validación de días y prendas
  @tarifa_base 3200
  @prendas_para_bonificacion 120
  @bonificacion_diaria 18_000
  @alquiler_por_dia 15_000

  @doc """
  Valor de un lote válido: prendas × tarifa base, con el ajuste por defectos.

  El ajuste se maneja en porcentaje entero y se divide al final por 100,
  para evitar errores de redondeo con decimales binarios.

  """
  def valor_lote(lote) do
    lote.prendas * @tarifa_base * (100 + ajuste_por_defectos(lote.defectos)) / 100
  end

  @doc """
  Ajuste en porcentaje según los defectos:
  hasta 2 % bonifica 7; hasta 5 % sin ajuste; hasta 10 % descuenta 12; más de 10 % descuenta 25.
  recibe un número defectos y devuelve un número entero que representa el ajuste en porcentaje
  """
  def ajuste_por_defectos(defectos) do
    cond do
      defectos <= 2 -> 7
      defectos <= 5 -> 0
      defectos <= 10 -> -12
      true -> -25
    end
  end

  @doc """
  Bonificación de un día según las prendas acumuladas ese día
  (suma de todos los lotes válidos, sin importar la línea).
  #bonificación diaria: $18.000 si se producen 120 prendas o más; cero en caso contrario.

  """
  def bonificacion_diaria(prendas_del_dia) when prendas_del_dia >= @prendas_para_bonificacion,
    do: @bonificacion_diaria
  def bonificacion_diaria(_prendas_del_dia), do: 0

  @doc """
  Descuento por alquiler: $15.000 por día trabajado solo si el confeccionista
  usa máquina del taller; cero en caso contrario.
  #descuento por alquiler: $15.000 por día trabajado solo si el confeccionista alquila máquina; cero en caso contrario.
  """
  def descuento_alquiler(%{alquiler: true}, dias_trabajados),
    do: dias_trabajados * @alquiler_por_dia

  def descuento_alquiler(_confeccionista, _dias_trabajados), do: 0

  @doc """
  Detalle por día de los lotes válidos de un confeccionista, ordenado por día.
  Solo aparecen los días con al menos un lote válido.
  detalle_por_dia/1 recibe una lista de lotes válidos y devuelve una lista de mapas, cada mapa contiene el día,
  la cantidad de prendas, el valor de los lotes y la bonificación diaria
  &1.dia accede al valor del campo dia del mapa, que representa el día de producción del lote
  Enum.group_by/2 agrupa los lotes por día, creando un mapa donde las claves son los días y
  los valores son listas de lotes correspondientes a cada día
  Enum.map/2 itera sobre cada par {dia, lotes_del_dia}, calculando la cantidad total de prendas y el valor total de los lotes para ese día
  Enum.sort_by/2 ordena la lista de mapas resultante por el campo dia, de manera ascendente, para que los días aparezcan en orden cronológico

  """
  def detalle_por_dia(lotes) do
    lotes
    |> Enum.group_by(& &1.dia)
    |> Enum.map(fn {dia, lotes_del_dia} ->
      prendas = lotes_del_dia |> Enum.map(& &1.prendas) |> Enum.sum()
      valor_lotes = lotes_del_dia |> Enum.map(&valor_lote/1) |> Enum.sum()

      %{
        dia: dia,
        prendas: prendas,
        valor_lotes: valor_lotes,
        bonificacion: bonificacion_diaria(prendas)
      }
    end)
    |> Enum.sort_by(& &1.dia)
  end

  @doc """
  Liquida a un confeccionista a partir de SUS lotes válidos.
  Devuelve un mapa con prendas, bruto (suma de lotes), bonificaciones,
  alquiler, neto y el detalle por día. Sin lotes válidos, todo es cero.
  liquidar_confeccionista/2 recibe un mapa confeccionista y una lista de lotes válidos, y
  devuelve un mapa con la liquidación del confeccionista
  Map.merge/2 combina el mapa de liquidación con un mapa adicional que contiene la suma
  de lotes y la suma de bonificaciones, para incluir esos valores en el resultado final
&.prendas accede al valor del campo prendas del mapa, que representa la cantidad de prendas producidas por el confeccionista
enum.sum/1 calcula la suma de los valores de una lista, en este caso, la suma de prendas, valores de lotes y bonificaciones
bruto + bonificaciones - alquiler calcula el neto del confeccionista, restando el descuento por alquiler del total de bruto y bonificaciones
  """
  def liquidar_confeccionista(confeccionista, lotes_validos) do
    dias = detalle_por_dia(lotes_validos)

    prendas = dias |> Enum.map(& &1.prendas) |> Enum.sum()
    bruto = dias |> Enum.map(& &1.valor_lotes) |> Enum.sum()
    bonificaciones = dias |> Enum.map(& &1.bonificacion) |> Enum.sum()
    alquiler = descuento_alquiler(confeccionista, length(dias))

    %{
      codigo: confeccionista.codigo,
      nombre: confeccionista.nombre,
      prendas: prendas,
      bruto: bruto,
      bonificaciones: bonificaciones,
      alquiler: alquiler,
      neto: bruto + bonificaciones - alquiler,
      dias: dias
    }
  end

  @doc """
  Liquida a TODOS los confeccionistas, incluso a quienes no tienen lotes válidos.
  Devuelve una lista de mapas en el mismo orden de `confeccionistas`.
  map.get/3 obtiene la lista de lotes válidos correspondientes al confeccionista actual, o una lista vacía si no hay lotes válidos
  group_by/2 agrupa los lotes válidos por el código del confeccionista, creando un mapa donde las claves son los códigos y los valores son listas de lotes
  Enum.map/2 itera sobre cada confeccionista, obteniendo sus lotes válidos
  """
  def liquidar(lotes_validos, confeccionistas) do
    lotes_por_codigo = Enum.group_by(lotes_validos, & &1.confeccionista)

    Enum.map(confeccionistas, fn confeccionista ->
      lotes = Map.get(lotes_por_codigo, confeccionista.codigo, [])
      liquidar_confeccionista(confeccionista, lotes)
    end)
  end

  @doc """
  Datos del comprobante individual de un confeccionista.
  Devuelve `{:ok, comprobante}` o `{:error, :confeccionista_desconocido}`.
  enum.find/2 busca el confeccionista en la lista de confeccionistas, comparando el código del confeccionista con el código proporcionado
  enum.filter/2 filtra los lotes válidos para obtener solo aquellos que pertenecen al confeccionista con el código especificado
  &1.confeccionista accede al valor del campo confeccionista del mapa, que representa el código del confeccionista asociado al lote
  """
  def comprobante(codigo, lotes_validos, confeccionistas) do
    case Enum.find(confeccionistas, &(&1.codigo == codigo)) do
      nil ->
        {:error, :confeccionista_desconocido}

      confeccionista ->
        lotes = Enum.filter(lotes_validos, &(&1.confeccionista == codigo))
        liquidacion = liquidar_confeccionista(confeccionista, lotes)

        {:ok,
         Map.merge(liquidacion, %{
           suma_lotes: liquidacion.bruto,
           suma_bonificaciones: liquidacion.bonificaciones
         })}
    end
  end
end
