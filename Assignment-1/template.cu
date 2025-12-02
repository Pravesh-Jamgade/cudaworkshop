#include <stdio.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include <chrono>
#include <string>
#include <cstring>
#include <fstream>
#include <iostream>
using namespace std;

__global__ void blurKernel(int *in, int *out, int N, int M)
{
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row >= N || col >= M)
        return;

    int sum = 0;
    int count = 0;

    for (int dy = -1; dy <= 1; dy++)
    {
        for (int dx = -1; dx <= 1; dx++)
        {
            int nRow = row + dy;
            int nCol = col + dx;

            if (nRow >= 0 && nRow < N && nCol >= 0 && nCol < M)
            {
                sum += in[nRow * M + nCol];
                count++;
            }
        }
    }

    int denom = count;
    out[row * M + col] = (sum + denom - 1) / denom; // ceiling of average
}

int main(int argc, char **argv)
{
    if (argc != 2)
    {
        std::cerr << "Usage: " << argv[0] << " <input_file>" << std::endl;
        return 1;
    }

    string inputFile = argv[1];
    // --- Generate output name automatically ---
    std::string outputPath;
    {
        // Find the number in the filename inputX.txt
        int num = -1;
        for (char c : inputFile)
        {
            if (isdigit(c))
            {
                if (num == -1)
                    num = c - '0';
                else
                    num = num * 10 + (c - '0');
            }
        }

        if (num == -1)
        {
            std::cerr << "Error: Input file name must contain a number like inputX.txt!" << std::endl;
            return 1;
        }

        outputPath = "output" + std::to_string(num) + ".txt";
    }
    FILE *fp = fopen(inputFile.c_str(), "r");

    if (!fp)
    {
        printf("Error opening input file!\n");
        return 1;
    }

    int N, M;
    fscanf(fp, "%d %d", &N, &M);

    int size = N * M;

    int *h_in = new int[size];
    int *h_out = new int[size];

    for (int i = 0; i < size; i++)
        fscanf(fp, "%d", &h_in[i]);

    fclose(fp);

    int *d_in, *d_out;

    // Do not change anything above this line .

    // Allocate memory to the GPU for input matrix and output matrix and store the address in d_in and d_out
    //  initalize the momory reserved in GPU.
    cudaMalloc(&d_in, size * sizeof(int));
    cudaMalloc(&d_out, size * sizeof(int));

    cudaMemcpy(d_in, h_in, size * sizeof(int), cudaMemcpyHostToDevice);

    auto t_start = chrono::high_resolution_clock::now();

    /*
        Define the threads configurations and launch the kernel
    */
    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (N + threadsPerBlock.y - 1) / threadsPerBlock.y);

    blurKernel<<<numBlocks, threadsPerBlock>>>(d_in, d_out, N, M);
    cudaDeviceSynchronize();

    // Do not change anything above this line
    auto t_end = chrono::high_resolution_clock::now();
    chrono::duration<double> elapsed = t_end - t_start;

    cudaMemcpy(h_out, d_out, size * sizeof(int), cudaMemcpyDeviceToHost);

    cudaFree(d_in);
    cudaFree(d_out);

    ofstream out(outputPath);
    if (!out.is_open())
    {
        cout << "Error writing output file!\n";
        return 1;
    }

    // Write matrix
    out << N << " " << M << "\n";
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < M; j++)
            out << h_out[i * M + j] << " ";
        out << "\n";
    }

    // Write time in seconds
    out << elapsed.count() << "\n";

    out.close();

    delete[] h_in;
    delete[] h_out;

    return 0;
}
