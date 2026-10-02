defmodule Programa do

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
    IO.puts("3. Mostrar lotes")
    IO.puts("4. Validar lotes")
    IO.puts("5. valor_lotes")
    IO.puts("6. salir")

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

      "3" ->
        IO.inspect(lotes, label: "Lotes existentes", limit: :infinity)
        menu(confeccionistas, lineas, lotes)

      "4" ->
        resultados =
          Enum.map(lotes, fn lote ->
            Validaciones.validar_lote(lote, confeccionistas, lineas)
          end)
        IO.inspect(resultados, label: "Resultados", limit: :infinity)
        menu(confeccionistas, lineas, lotes)

#el Enum.filter se utiliza para filtrar los lotes válidos, y luego se calcula el valor
#de cada lote válido utilizando la función valor_lote del módulo Liquidacion. Finalmente,
#se imprime el resultado en la consola.
      "5" ->
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
      "6" ->
        IO.puts("Saliendo del programa...")
      _ ->
        IO.puts("Opción inválida. Intente nuevamente.")
        menu(confeccionistas, lineas, lotes)

    end
  end
end

Programa.main()
