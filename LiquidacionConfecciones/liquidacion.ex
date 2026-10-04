defmodule Liquidacion do
  @precio_base 3200
  @meta_bonificacion 120
  @bonificacion 18_000
  @alquiler 15_000


  def valor_lote(lote) do

  # Calculamos el valor base del lote multiplicando la cantidad de prendas por 3200
  valor_base = lote.prendas * @precio_base
  # Cond se utiliza para determinar el valor final según los defectos
    cond do
      lote.defectos <= 2 -> valor_base + (valor_base * 0.07)
      lote.defectos >2 and lote.defectos <= 5 -> valor_base
      lote.defectos > 5 and lote.defectos <= 10 -> valor_base - (valor_base * 0.12)
      lote.defectos > 10 -> valor_base - (valor_base * 0.25)
    end




  end

  @doc """
  Recibe la lista de lotes validos de un confeccionista y agrupa los lotes por día, despues suma las prendas de cada día y si se alcanzo el minimo para la bonificacion suma los 18k de
  """
  def calcular_bonificaciones(lotes_del_confeccionista) do
    lotes_del_confeccionista
    |> Enum.group_by(fn lote -> lote.dia end)
    |> Enum.reduce(0, fn {_dia, lotes_dia}, acumulado_bonos ->
      #se suman todas las prendas de los lotes de ese dia
      prendas_dia = Enum.reduce(lotes_dia, 0, fn lote, acc -> acc + lote.prendas end)

      if prendas_dia >= @meta_bonificacion do
        acumulado_bonos + @bonificacion
      else
        acumulado_bonos
      end
    end)
  end

  @doc """
  Verifica si el confeccionista tiene alquilada una maquina y si es asi cuenta los días en que tiene un lote válido y multiplica esa cantidad de días por @alquiler
  """
  def calcular_alquiler(lotes_del_confeccionista, confeccionista) do
    if confeccionista.alquiler do
      dias_trabajados =
        lotes_del_confeccionista
        |> Enum.map(fn lote -> lote.dia end)
        |> Enum.uniq()
        |> Enum.count()

      dias_trabajados * @alquiler
    else
      0
    end
  end

  @doc """
  recibe un mapa de confeccionista y la lista de todos los lotes marcados con valido de el , despues de hechas las operaciones retorna un mapa para mostrarse en pantalla
  en caso de no tener lotes retorna 0 en todos los campos del mapa
  """
  def liquidar_confeccionista(confeccionista, lotes_validos_totales) do
    #se filtran los lotes que le pertenecen al confeccionista
    lotes_confeccionista = Enum.filter(lotes_validos_totales, fn lote ->
      lote.confeccionista == confeccionista.codigo
    end)

    #se le agrega el valor a cada lote individual para el reporte
    lotes_con_valor = Enum.map(lotes_confeccionista, fn lote ->
      Map.put(lote, :valor_calculado, valor_lote(lote))
    end)

    #se calculan los totales
    suma_lotes = Enum.reduce(lotes_con_valor, 0, fn lote, acc -> acc + lote.valor_calculado end)
    bonificaciones = calcular_bonificaciones(lotes_confeccionista)
    descuento_alquiler = calcular_alquiler(lotes_confeccionista, confeccionista)

    #se calcula el total neto
    neto = suma_lotes + bonificaciones - descuento_alquiler

    #estructura del mapa
    %{
      confeccionista: confeccionista,
      lotes_detalle: lotes_con_valor,
      suma_lotes: suma_lotes,
      bonificaciones: bonificaciones,
      descuento_alquiler: descuento_alquiler,
      neto: neto
    }
  end
end
