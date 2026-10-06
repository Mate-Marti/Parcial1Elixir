defmodule Programa do
@moduledoc """
  Módulo que contiene el programa principal para la liquidación de confeccionistas.
  verción 1.0
  autores:Jofrer Ivan Lopez Lizcano, Sara Sofia Salazar, Mateo Martines Rincon
  fecha: 2026-10-04
  """


  def main do
    confeccionistas = Datos.confeccionistas()
    lineas = Datos.lineas()
    lotes = Datos.lotes()

    menu(confeccionistas, lineas, lotes)
  end

  def menu(confeccionistas, lineas, lotes) do
    IO.puts("\nMenú de opciones:")
    IO.puts("1. Mostrar confeccionistas")
    IO.puts("2. Mostrar líneas")
    IO.puts("3. Crear lotes")
    IO.puts("4. Mostrar lotes")
    IO.puts("5. Validar lotes")
    IO.puts("6. Valor de lotes")
    IO.puts("7. Liquidación del confeccionista")
    IO.puts("8. Reportes")
    IO.puts("9. rank y merge")
    IO.puts("10. salir")

    opcion = IO.gets("Seleccione una opción: ")
    |> String.trim()

    # utilizamos case para tomar decisiones a través del menú

    case opcion do
      "1" ->
        IO.inspect(confeccionistas, label: "Confeccionistas existentes")
        menu(confeccionistas, lineas, lotes)

      "2" ->
        IO.inspect(lineas, label: "Líneas existentes")
        menu(confeccionistas, lineas, lotes)

        #se usa la validacion de entrada para los datos que netran
        #se usa la validacion de lote para verificar que se haya creado bien
        #se hace aparecer el menu y se pega el lote nuevo a la lista
      "3" ->
        IO.puts("\nTenga en cuenta que el formato es asi: (confeccionista;linea;dia;prendas;defectos), por ejemplo: C01;L1;1;100;1.5")

        entrada = IO.gets("Ingrese los datos del lote que quiere agregar,y si quiere salir oprima enter:  ") |> String.trim()

        case Validaciones.entrada_lote(entrada) do
          {:ok, :omitido} ->
            IO.puts("La creacion del lote fue omitida")
            menu(confeccionistas, lineas, lotes)

          {:error, :formato_invalido} ->
            IO.puts("Error: formato invalido")
            menu(confeccionistas, lineas, lotes)

          {:ok, lote_nuevo} ->

            case Validaciones.validar_lote(lote_nuevo, confeccionistas, lineas) do
              {:ok, _} ->
                IO.puts("Lote agregado")
                menu(confeccionistas, lineas, [lote_nuevo | lotes])

              {:error, motivo} ->
                IO.puts("Lote rechazado ya que: #{motivo}")
                menu(confeccionistas, lineas, lotes)
            end
        end

      "4" ->
        IO.inspect(lotes, label: "Lotes existentes", limit: :infinity)
        menu(confeccionistas, lineas, lotes)

      "5" ->
        resultados =
          Enum.map(lotes, fn lote ->
            Validaciones.validar_lote(lote, confeccionistas, lineas)
          end)
        IO.inspect(resultados, label: "Resultados", limit: :infinity)
        menu(confeccionistas, lineas, lotes)

#el Enum.filter se utiliza para filtrar los lotes válidos, y luego se calcula el valor
#de cada lote válido utilizando la función valor_lote del módulo Liquidacion. Finalmente,
#se imprime el resultado en la consola.
      "6" ->
        resultados =
          lotes
          |> Enum.filter(fn lote ->
            case Validaciones.validar_lote(lote, confeccionistas, lineas) do
              {:ok, _} -> true
              {:error, _} -> false
            end
          end)
          |> Enum.map(fn lote ->
            valor = Liquidacion.valor_lote(lote)
            {lote, valor}
          end)
        IO.inspect(resultados, label: "Valores de lotes válidos", limit: :infinity)
        menu(confeccionistas, lineas, lotes)

        #se filtran los lotes validos en lotes_validos
        #se pide el codigo del confeccionista en buscar_confeccionista
        #se busca al confeccionista
        #*en el if*: se le asigna a resultado la liquidacion que se hizo
        #            se imprime la tabla porpuesta como en el ejemplo
      "7" ->
        lotes_validos =
          Enum.filter(lotes, fn lote ->
            case Validaciones.validar_lote(lote, confeccionistas, lineas) do
              {:ok, _} -> true
              {:error, _} -> false
            end
          end)

        buscar_confeccionista = IO.gets("ingrese el codigo del confeccionista para liquidar: ") |> String.trim()

        confeccionista = Enum.find(confeccionistas, fn c -> c.codigo == buscar_confeccionista end)

        if confeccionista do

          resultado = Liquidacion.liquidar_confeccionista(confeccionista, lotes_validos)

          IO.puts("Nombre del confeccionista: #{resultado.confeccionista.nombre} , y alquilo maquina?: #{resultado.confeccionista.alquiler}")
          IO.puts("Dia\tLinea\tPrendas\tDefectos\tValor de Lote")

          Enum.each(resultado.lotes_detalle, fn lote ->
            IO.puts("#{lote.dia}\t#{lote.linea}\t#{lote.prendas}\t#{lote.defectos}%\t\t$#{:erlang.float_to_binary(lote.valor_calculado * 1.0, decimals: 2)}")
          end)

          IO.puts("Suma de los lotes: $#{:erlang.float_to_binary(resultado.suma_lotes * 1.0, decimals: 2)}")
          IO.puts("Bonificaciones: $#{:erlang.float_to_binary(resultado.bonificaciones * 1.0, decimals: 2)}")
          IO.puts("Descuento alquiler: -$#{:erlang.float_to_binary(resultado.descuento_alquiler * 1.0, decimals: 2)}")
          IO.puts("Total para pagar: $#{:erlang.float_to_binary(resultado.neto * 1.0, decimals: 2)}")

        else
          IO.puts("Confeccionista no encontrado")
        end
        menu(confeccionistas, lineas, lotes)

      "8" ->
        Reportes.todos_los_reportes(lotes, confeccionistas, lineas)
        menu(confeccionistas, lineas, lotes)


      "9" ->
      # Preparamos las liquidaciones para el C.1
      lotes_validos = Enum.filter(lotes, fn l -> match?({:ok, _}, Validaciones.validar_lote(l, confeccionistas, lineas)) end)

      liquidaciones =
          Enum.map(confeccionistas, fn conf ->
            liq = Liquidacion.liquidar_confeccionista(conf, lotes_validos)
            prendas_totales = Enum.reduce(liq.lotes_detalle, 0, fn lote, acc -> acc + lote.prendas end)

            liq
            |> Map.put(:prendas, prendas_totales)
            |> Map.put(:bruto, liq.suma_lotes) # El bruto es la suma antes de bonos/alquiler
          end)

      # C.1: Las 3 llamadas obligatorias del PDF
      Reportes.ranking(liquidaciones, [])
      Reportes.ranking(liquidaciones, campo: :prendas, limite: 3)
      Reportes.ranking(liquidaciones, orden: :asc, campo: :bruto)

      # C.2: Llamada a combinar talleres
      produccion = Reportes.produccion_diaria(lotes_validos)
      Reportes.combinar_talleres(produccion)

      menu(confeccionistas, lineas, lotes)



      "10" ->
        IO.puts("Saliendo del programa...")
      _ ->
        IO.puts("Opción inválida. Intente nuevamente.")
        menu(confeccionistas, lineas, lotes)

    end
  end
end

Programa.main()
